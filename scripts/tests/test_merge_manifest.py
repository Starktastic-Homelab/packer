#!/usr/bin/env python3
"""Tests for scripts/merge-manifest.sh, the manifest merge push-manifest runs in build.yml.

Run: python3 scripts/tests/test_merge_manifest.py  (stdlib; needs bash and jq on PATH)
"""

import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/merge-manifest.sh"


FIXTURE = ROOT / "scripts/tests/fixtures/run-149-manifests.json"


def build(role, uuid, name=None):
    """A manifest entry as merged: name == role. Pass name to get what Packer wrote (it may be the source label)."""
    custom = {"vm_name": f"packer-{role}-{uuid}"}
    if role != "debian-13":
        custom["role"] = role
    return {
        "name": name or role,
        "artifact_id": {"k3s": "901", "storage": "902"}.get(role, "900"),
        "packer_run_uuid": uuid,
        "custom_data": custom,
    }


def needs(**jobs):
    """push-manifest's toJSON(needs): {role: (result, [builds])}."""
    return {
        role: {"result": result, "outputs": {"manifest": json.dumps({"builds": builds}) + "\n"} if result == "success" else {}}
        for role, (result, builds) in jobs.items()
    }


class TestMergeManifest(unittest.TestCase):
    def merge(self, needs_doc, current):
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for name, doc in (("needs.json", needs_doc), ("current.json", current)):
                path = Path(d) / name
                path.write_text(json.dumps(doc))
                paths.append(str(path))
            return subprocess.run(["bash", str(SCRIPT), *paths], capture_output=True, text=True)

    def merged(self, needs_doc, current):
        result = self.merge(needs_doc, current)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_merges_every_successful_build(self):
        k3s, storage = build("k3s", "k"), build("storage", "s")
        out = self.merged(needs(k3s=("success", [k3s]), storage=("success", [storage])),
                          {"builds": [build("debian-13", "d")], "last_run_uuid": "d"})
        self.assertEqual([b["name"] for b in out["builds"]], ["k3s", "debian-13", "storage"])
        self.assertEqual(out["builds"][0], k3s)
        self.assertEqual(out["builds"][2], storage)
        self.assertIn(out["last_run_uuid"], ("k", "s"))

    def test_failed_build_keeps_its_old_entry(self):
        old_storage = build("storage", "old-s")
        current = {"builds": [build("k3s", "old"), build("debian-13", "d"), old_storage], "last_run_uuid": "old"}
        out = self.merged(needs(k3s=("success", [build("k3s", "new")]), storage=("failure", [])), current)
        self.assertEqual(out["builds"], [build("k3s", "new"), build("debian-13", "d"), old_storage])
        self.assertEqual(out["last_run_uuid"], "new")

    def test_replaces_old_entries(self):
        current = {"builds": [build("k3s", "old"), build("debian-13", "d"), build("storage", "old-s")]}
        out = self.merged(needs(k3s=("success", [build("k3s", "older"), build("k3s", "new")]),
                                storage=("success", [build("storage", "new-s")])), current)
        self.assertEqual(out["builds"], [build("k3s", "new"), build("debian-13", "d"), build("storage", "new-s")])

    def test_no_successful_build_fails_silently(self):
        result = self.merge(needs(k3s=("failure", []), storage=("failure", [])), {"builds": [build("k3s", "old")]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_success_without_its_build_fails(self):
        result = self.merge(needs(k3s=("success", [build("storage", "s")]), storage=("failure", [])),
                            {"builds": [build("k3s", "old")]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_later_role_without_its_build_prints_nothing(self):
        # A good k3s merge before the failing storage one must not reach stdout: the script prints once, at the end.
        result = self.merge(needs(k3s=("success", [build("k3s", "k")]), storage=("success", [build("k3s", "x")])),
                            {"builds": [build("k3s", "old")]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_source_label_names_merge_by_role(self):
        # Run 149 (Packer 1.16.2, hashicorp/packer#12482): every clone build is named after the source label "clone".
        k3s, storage = build("k3s", "k", name="clone"), build("storage", "s", name="clone")
        out = self.merged(needs(k3s=("success", [k3s]), storage=("success", [storage])),
                          {"builds": [build("debian-13", "d")], "last_run_uuid": "d"})
        self.assertEqual([b["name"] for b in out["builds"]], ["k3s", "debian-13", "storage"])
        self.assertEqual(out["builds"][0], {**k3s, "name": "k3s"})
        self.assertEqual(out["builds"][2], {**storage, "name": "storage"})

    def test_run_149_manifests_merge(self):
        # The verbatim run 149 job outputs, plus the custom_data.role the build files now write.
        manifests = json.loads(FIXTURE.read_text())
        jobs = {}
        for role, manifest in manifests.items():
            self.assertEqual({b["name"] for b in manifest["builds"]}, {"clone"})
            for b in manifest["builds"]:
                b["custom_data"]["role"] = role
            jobs[role] = ("success", manifest["builds"])
        out = self.merged(needs(**jobs), {"builds": [build("k3s", "old"), build("debian-13", "d")]})
        self.assertEqual([b["name"] for b in out["builds"]], ["k3s", "debian-13", "storage"])
        self.assertEqual([b["artifact_id"] for b in out["builds"]], ["901", "900", "902"])
        self.assertEqual(out["builds"][0]["custom_data"]["vm_name"], "packer-k3s-debian-13.8.0-20261124041357")
        self.assertEqual(out["builds"][2]["custom_data"]["vm_name"], "packer-storage-debian-13.8.0-20261124041159")

    def test_build_without_role_fails(self):
        # An entry that does not say its role is not taken, whatever Packer named it.
        unmarked = build("k3s", "k")
        del unmarked["custom_data"]["role"]
        result = self.merge(needs(k3s=("success", [unmarked])), {"builds": [build("k3s", "old")]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_push_manifest_uses_script(self):
        text = (ROOT / ".github/workflows/build.yml").read_text()
        job = re.split(r"(?m)^  push-manifest:\n", text)[1]
        job = re.split(r"(?m)^  [\w-]+:\n", job)[0]
        self.assertIn("NEEDS: ${{ toJSON(needs) }}", job)
        self.assertIn('scripts/merge-manifest.sh "$RUNNER_TEMP/needs.json" packer-manifest.json', job)
        self.assertNotIn("jq --argjson", job)
        self.assertNotIn("needs.k3s.outputs", job)


if __name__ == "__main__":
    unittest.main(verbosity=2)

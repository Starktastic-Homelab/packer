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


def build(name, uuid):
    return {
        "name": name,
        "artifact_id": {"k3s": "901", "storage": "902"}.get(name, "900"),
        "packer_run_uuid": uuid,
        "custom_data": {"vm_name": f"packer-{name}-{uuid}"},
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

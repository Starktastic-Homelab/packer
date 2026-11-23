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
    return {"name": name, "packer_run_uuid": uuid, "custom_data": {"vm_name": f"packer-{name}-{uuid}"}}


class TestMergeManifest(unittest.TestCase):
    def merge(self, role, new, current):
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for name, doc in (("new.json", new), ("current.json", current)):
                path = Path(d) / name
                path.write_text(json.dumps(doc))
                paths.append(str(path))
            return subprocess.run(["bash", str(SCRIPT), role, *paths], capture_output=True, text=True)

    def merged(self, role, new, current):
        result = self.merge(role, new, current)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_adds_k3s_first(self):
        new = {"builds": [build("k3s", "new")], "last_run_uuid": "new"}
        out = self.merged("k3s", new, {"builds": [build("debian-13", "d")], "last_run_uuid": "d"})
        self.assertEqual([b["name"] for b in out["builds"]], ["k3s", "debian-13"])
        self.assertEqual(out["builds"][0], build("k3s", "new"))
        self.assertEqual(out["last_run_uuid"], "new")

    def test_replaces_old_k3s(self):
        new = {"builds": [build("k3s", "older"), build("k3s", "new")], "last_run_uuid": "new"}
        current = {"builds": [build("k3s", "old"), build("debian-13", "d")], "last_run_uuid": "old"}
        out = self.merged("k3s", new, current)
        self.assertEqual(out["builds"], [build("k3s", "new"), build("debian-13", "d")])

    def test_keeps_other_entries(self):
        storage = build("storage", "s")
        current = {"builds": [build("k3s", "old"), storage], "last_run_uuid": "old"}
        out = self.merged("k3s", {"builds": [build("k3s", "new")]}, current)
        self.assertEqual(out["builds"], [build("k3s", "new"), storage])

    def test_missing_role_fails_silently(self):
        result = self.merge("k3s", {"builds": [build("storage", "s")]}, {"builds": [build("k3s", "old")]})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_push_manifest_uses_script(self):
        text = (ROOT / ".github/workflows/build.yml").read_text()
        job = re.split(r"(?m)^  push-manifest:\n", text)[1]
        job = re.split(r"(?m)^  [\w-]+:\n", job)[0]
        self.assertIn("scripts/merge-manifest.sh k3s", job)
        self.assertNotIn("jq --argjson", job)


if __name__ == "__main__":
    unittest.main(verbosity=2)

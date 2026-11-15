#!/usr/bin/env python3
"""Offline layout tests for the base, k3s and storage images (ADR 0017).

Run: python3 scripts/tests/test_image_layout.py

Stdlib only: HCL, shell and workflow files are checked as text. Building an
image still needs a real `packer build`; these tests pin the layout around it.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROLES = ("base", "k3s", "storage")
CLONES = ("k3s", "storage")
GPU_PACKAGES = {
    "build-essential",
    "dkms",
    "linux-headers-amd64",
    "nfs-common",
    "firmware-misc-nonfree",
    "intel-media-va-driver-non-free",
    "vainfo",
}
LVM_DROPIN = """[Unit]
Wants=network-online.target
After=network-online.target

[Service]
ExecStartPre=/sbin/vgchange -ay retained
ExecStartPre=-/sbin/vgchange -ay regen
"""


def read(rel):
    return (ROOT / rel).read_text()


def shell_commands(text):
    """Logical command lines: comments dropped, backslash continuations joined."""
    text = re.sub(r"\s*\\\n\s*", " ", text)
    lines = [line.strip() for line in text.splitlines()]
    return [line for line in lines if line and not line.startswith("#")]


def installs(rel):
    packages = set()
    for line in shell_commands(read(rel)):
        if re.match(r"apt(-get)? install\b", line):
            packages |= {w for w in line.split()[2:] if not w.startswith("-")}
    return packages


def provisioners(rel):
    """Provisioner block bodies of a build file, in order."""
    text = read(rel).split('post-processor "manifest"')[0]
    return text.split('provisioner "')[1:]


def setting(key, value):
    return rf'(?m)^\s*{re.escape(key)}\s*=\s*{re.escape(value)}\s*$'


def workflow_jobs(text):
    body = text.split("\njobs:\n", 1)[1]
    parts = re.split(r"(?m)^  ([\w-]+):\n", body)
    return dict(zip(parts[1::2], parts[2::2]))


class TestImageLayout(unittest.TestCase):
    def test_old_single_image_files_are_gone(self):
        for rel in ("source.pkr.hcl", "build.pkr.hcl", "scripts/bootstrap.sh", "scripts/delete_builder_user.sh"):
            self.assertFalse((ROOT / rel).exists(), rel)

    def test_vm_ids_and_names(self):
        variables = read("variables.pkr.hcl")
        for name, default in (("base_vm_id", "900"), ("k3s_vm_id", "901"), ("storage_vm_id", "902"),
                              ("vm_name_prefix", '"packer"')):
            self.assertRegex(variables, rf'variable "{name}" {{\n  default = {default}\n}}')
        self.assertNotIn('variable "vm_id"', variables)
        config = read("config.pkr.hcl")
        self.assertIn('debian = regex("debian-\\\\d+\\\\.\\\\d+\\\\.\\\\d+", var.iso_name)', config)
        self.assertIn('role => "${var.vm_name_prefix}-${role}-${local.debian}-${local.stamp}"', config)
        self.assertIn('for role in ["base", "k3s", "storage"]', config)

    def test_sources_and_manifests(self):
        kinds = {"base": "proxmox-iso", "k3s": "proxmox-clone", "storage": "proxmox-clone"}
        for role in ROLES:
            source = read(f"source-{role}.pkr.hcl")
            self.assertIn(f'source "{kinds[role]}" "{role}" {{', source)
            self.assertRegex(source, setting("vm_id", f"var.{role}_vm_id"))
            self.assertRegex(source, setting("vm_name", f"local.vm_name.{role}"))
            build = read(f"build-{role}.pkr.hcl")
            self.assertIn(f'sources = ["source.{kinds[role]}.{role}"]', build)
            manifest = build.split('post-processor "manifest"')[1]
            self.assertRegex(manifest, setting("vm_name", f"local.vm_name.{role}"))
            self.assertRegex(manifest, setting("git_tag", f'"v${{join(".", regex("(\\\\d+\\\\.\\\\d+\\\\.\\\\d+)-(\\\\d+)", local.vm_name.{role}))}}"'))
            gpu_pair = "i915_sriov_version" in manifest and "i915_sriov_kernel_series" in manifest
            self.assertEqual(gpu_pair, role == "k3s", role)

    def test_preseed_has_no_compiler(self):
        lines = re.findall(r"(?m)^d-i pkgsel/include string (.*)$", read("http/preseed.cfg.tmpl"))
        self.assertEqual(lines, ["qemu-guest-agent openssh-server"])

    def test_clone_sources_inject_key(self):
        for role in CLONES:
            source = read(f"source-{role}.pkr.hcl")
            with self.subTest(role=role):
                self.assertRegex(source, setting("ssh_username", "var.builder_creds.username"))
                self.assertNotRegex(source, r"ssh_password|ssh_private_key_file|ssh_agent_auth|ssh_keypair_name")
                self.assertRegex(source, setting("clone_vm_id", "var.base_vm_id"))
                self.assertRegex(source, setting("task_timeout", '"10m"'))
                self.assertRegex(source, setting("cloud_init", "true"))
                self.assertRegex(source, setting("cloud_init_storage_pool", "var.disk_storage_pool"))
                # proxmox-clone re-applies hardware from its own config, with plugin defaults otherwise.
                for key, value in (("os", '"l26"'), ("machine", '"q35"'), ("cpu_type", "var.cpu_type"),
                                   ("cores", "var.cores"), ("memory", "var.memory"),
                                   ("scsi_controller", "var.scsi_controller"), ("qemu_agent", "true")):
                    self.assertRegex(source, setting(key, value))
                self.assertRegex(source, r'network_adapters \{\n\s+model\s+= "virtio"\n\s+bridge = var.network_adapter_bridge\n')
                self.assertNotIn("disks {", source)  # clone keeps the base disk; declared disks are appended

    def test_seal_contents(self):
        for role in ROLES:
            blocks = provisioners(f"build-{role}.pkr.hcl")
            with self.subTest(role=role):
                self.assertEqual([b for b in blocks if "scripts/seal.sh" in b], [blocks[-1]])
                seal = blocks[-1]
                self.assertRegex(seal, setting("skip_clean", "true"))  # it deletes the logged-in user
                self.assertRegex(seal, setting("BUILDER_USER", "var.builder_creds.username"))
                self.assertEqual(bool(re.search(setting("CLONE_BUILD", '"1"'), seal)), role in CLONES)
        script = read("scripts/seal.sh")
        order = [
            "truncate -s 0 /etc/machine-id",
            "rm -f /var/lib/dbus/machine-id",
            "ln -s /etc/machine-id /var/lib/dbus/machine-id",
            "cloud-init clean --logs",
            'userdel -r -f "$BUILDER_USER"',
            'if getent passwd "$BUILDER_USER" >/dev/null; then',
            'rm -f /etc/sudoers.d/"$BUILDER_USER"',
        ]
        positions = [script.index(s) for s in order]
        self.assertEqual(positions, sorted(positions))
        self.assertRegex(script, r'if getent passwd "\$BUILDER_USER" >/dev/null; then\n(?:  .*\n)*  exit 1\nfi\n')
        self.assertEqual(script.count("90-cloud-init-users"), 1)
        self.assertRegex(script, r'if \[ "\$\{CLONE_BUILD:-0\}" = 1 \]; then\n  rm -f /etc/sudoers.d/90-cloud-init-users\nfi\n')

    def test_clone_scripts_wait_for_cloud_init(self):
        for role in CLONES:
            commands = shell_commands(read(f"scripts/{role}.sh"))
            first_apt = next(i for i, c in enumerate(commands) if re.match(r"apt(-get|-mark)? ", c))
            wait = next(i for i, c in enumerate(commands) if c.startswith("cloud-init status --wait"))
            self.assertLess(wait, first_apt, role)

    def test_gpu_stack_only_in_k3s(self):
        self.assertLessEqual(GPU_PACKAGES, installs("scripts/k3s.sh"))
        self.assertIn("cloud-init", installs("scripts/base.sh"))
        for script in ("base", "storage", "seal"):
            rel = f"scripts/{script}.sh"
            with self.subTest(script=script):
                self.assertFalse(GPU_PACKAGES & installs(rel))
                self.assertNotIn("i915", read(rel))
                self.assertNotIn("modemmanager", read(rel))
        # A baked open-iscsi would give every clone the same IQN (ADR 0017).
        for path in sorted((ROOT / "scripts").glob("*.sh")):
            self.assertNotIn("open-iscsi", path.read_text(), path.name)

    def test_storage_script(self):
        script = read("scripts/storage.sh")
        commands = shell_commands(script)
        self.assertIn("apt install -y targetcli-fb lvm2 nftables prometheus-node-exporter", commands)
        self.assertIn("systemctl enable nftables", commands)
        self.assertIn("apt-mark hold python3-rtslib-fb targetcli-fb", commands)
        self.assertIn(
            "install -D -m 0644 /tmp/rtslib-fb-targetctl.service.d/10-lvm.conf "
            "/etc/systemd/system/rtslib-fb-targetctl.service.d/10-lvm.conf",
            commands,
        )
        self.assertRegex(
            script,
            r"for pkg in build-essential gcc; do\n"
            r"  if dpkg-query -W -f='\$\{db:Status-Status\}' \"\$pkg\" 2>/dev/null \| grep -qx installed; then\n"
            r"(?:    .*\n)*    exit 1\n  fi\ndone\n",
        )
        blocks = provisioners("build-storage.pkr.hcl")
        upload = next(i for i, b in enumerate(blocks) if 'source      = "files/storage/rtslib-fb-targetctl.service.d"' in b)
        run = next(i for i, b in enumerate(blocks) if "scripts/storage.sh" in b)
        self.assertLess(upload, run)

    def test_lvm_dropin(self):
        self.assertEqual(read("files/storage/rtslib-fb-targetctl.service.d/10-lvm.conf"), LVM_DROPIN)

    def test_build_workflow_order(self):
        text = read(".github/workflows/build.yml")
        jobs = workflow_jobs(text)
        self.assertEqual(
            set(jobs), {"base", "k3s", "storage", "create-release", "push-manifest", "push-storage-manifest"}
        )
        self.assertRegex(text, r"(?m)^concurrency:\n  group: \S+\n  cancel-in-progress: false\n")
        self.assertIn("packer build -force -only='proxmox-iso.base' .", jobs["base"])
        self.assertNotIn("needs:", jobs["base"])
        for role in CLONES:
            self.assertIn("    needs: base\n", jobs[role])
            self.assertIn(f"packer build -force -only='proxmox-clone.{role}' .", jobs[role])
        for job in ("create-release", "push-manifest"):
            self.assertIn("    needs: k3s\n", jobs[job])
            self.assertIn('select(.name=="k3s")', jobs[job])
        self.assertIn("    needs: storage\n", jobs["push-storage-manifest"])
        self.assertIn('select(.name=="storage")', jobs["push-storage-manifest"])
        merge = "'.builds = ([.builds[] | select(.name != $new.name)] + [$new] | sort_by(.name != \"k3s\"))"
        for job in ("push-manifest", "push-storage-manifest"):
            self.assertIn(merge, jobs[job])
        self.assertNotIn(".builds[0]", text)  # select by name, never by index

    def test_image_test_runs_in_ci(self):
        self.assertIn("python3 scripts/tests/test_image_layout.py", read(".github/workflows/validate.yml"))

    def test_pkrvars_keys_unchanged(self):
        text = read("debian.auto.pkrvars.hcl")
        self.assertEqual(
            re.findall(r"(?m)^(\w+)\s*=", text), ["iso_name", "i915_sriov_version", "i915_sriov_kernel_series"]
        )
        self.assertRegex(
            text, r"# renovate: datasource=github-releases depName=strongtz/i915-sriov-dkms\ni915_sriov_version = "
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)

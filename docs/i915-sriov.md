# i915 SR-IOV: acceptance, checker and branch protection

> Moved from the README on 2026-11-16. The text is unchanged.

After deploying new guest images, run the Ansible repository's
`i915-acceptance.yml` current-stack workflow. It compares the loaded guest
release/kernel against the declared target and runs generic nonroot H.264,
HEVC and HDR GPU probes on every inventory worker, without depending on
application deployments. It does not label that result as a proven host
reboot. Host-driver upgrades have a separate post-reboot mode tied to the
installation's saved pre-change identities.

```console
$ python3 scripts/i915_compat.py \
    --host-version 2026.09.14 --host-kernel 6.17.13-13-pve \
    --guest-version 2025.12.10.2 --guest-kernel 6.12
# exit 0 = metadata/policy passed, hardware NOT TESTED
# exit 1 = unsupported or blocked · 2 = metadata cannot be established
```

Two layers protect the image build:

1. **CI** (`i915-compat.yml`) validates the declared guest driver + kernel
   series against the host state on the ansible repo's `main`, and posts the
   report as a sticky PR comment, without claiming runtime acceptance.
2. **Build** (`scripts/bootstrap.sh`) re-checks the kernel the image *actually*
   has (running plus every installed `/lib/modules` kernel) against
   `i915_sriov_kernel_series` before installing the DKMS package, so a Debian
   kernel bump fails the build instead of shipping a broken template. After
   installing it, the build fails unless DKMS reports the module `installed`
   for the kernel the image boots: `dpkg -i` exits 0 even when the DKMS
   compile fails, which shipped a template without the SR-IOV driver
   (build 143, kernel `6.12.115+deb13.1`).

Renovate may only propose releases on the `2025.12.10.x` line
(`allowedVersions` in `renovate.json`), and its PRs still have to pass
`i915-compat` — a newer version number alone can never merge.

The actual required-check list is versioned in
`.github/required-status-checks.json`; it replaces the obsolete
`Verify Proxmox host driver is updated` context with the metadata/policy gate.
After the named checks exist and pass, an authorized administrator can apply
the list without replacing other branch protections:

```sh
gh api --method PATCH \
  repos/Starktastic-Homelab/packer/branches/main/protection/required_status_checks \
  --input .github/required-status-checks.json
```

**Moving the guest to a newer line** (e.g. when Debian ships a 6.17+ kernel):
update `i915_sriov_version` and `i915_sriov_kernel_series` in
`debian.auto.pkrvars.hcl`, widen `allowedVersions` in `renovate.json`, and let
`i915-compat` confirm the new pair.

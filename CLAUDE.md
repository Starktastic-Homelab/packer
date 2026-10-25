# packer

Builds the Debian 13 Proxmox VM template (VM ID 900) that every K3s node is cloned from. Stage 1 of
packer → terraform → ansible → apps; the system overview is `../CLAUDE.md` (from the `.github` repo).

## What runs live

- **Every push to `main` is a real build** (`.github/workflows/build.yml`): `packer build -force` on the
  self-hosted runner replaces template 900, publishes a GitHub release, and opens a `packer-build-<run>`
  PR in `terraform` with the new manifest. Only `README.md` and `renovate.json` are path-ignored, so
  docs-only commits (including this file) need `[skip ci]` in the subject.
- `format.yml` pushes "style: apply automatic formatting" commits to PR branches; pull before pushing.
- `check-debian-iso.yml` runs weekly and opens `update-debian-iso-*` PRs.

## Commands

```sh
packer fmt -check -diff -recursive .
packer init -upgrade .                       # downloads plugins
PKR_VAR_proxmox_api_url=https://proxmox.example.com:8006/api2/json \
PKR_VAR_proxmox_api_token_id=id PKR_VAR_proxmox_api_token_secret=secret \
  packer validate .                          # placeholders from validate.yml; builds nothing
python3 scripts/tests/test_i915_compat.py    # offline; I915_COMPAT_LIVE=1 adds a live GitHub test
shellcheck scripts/*.sh
shfmt -i 2 -ci -s -d scripts/
pre-commit run --files <changed files>       # the packer-fmt hook rewrites the whole repo
```

If a tool is missing, say so instead of installing it.

## Safe vs ask first

- Safe to run freely: everything under Commands.
- Ask first: `packer build` in any form, `gh workflow run`, `gh release`, merging PRs, pushing to `main`
  without `[skip ci]`, and anything that talks to the live Proxmox host.

## Before calling a change done

Run the fmt check, validate, the i915 test and shellcheck for what you touched, and report what ran and
what couldn't. "Validated" is not "built": only a real build proves the image, and only ansible's
`i915-acceptance.yml` proves the GPU.

## Gotchas and past decisions

- `scripts/bootstrap.sh` migrates ifupdown → Netplan *after* the i915 driver download; doing it earlier
  broke the download (f9f0b6d).
- `firmware-misc-nonfree` provides the i915 GuC/HuC blobs; without it there is no `renderD128` (#78).
- Driver 2026.05.03 failed DKMS (`BUILD_EXCLUSIVE` vs Debian kernel strings) and was reverted (#93).
- ModemManager is purged because it interferes with Zigbee USB serial adapters (#81).
- `delete_builder_user.sh` needs `skip_clean = true`: it deletes the user Packer is logged in as.
- The manifest `git_tag` is regex-derived from `vm_name` (`config.pkr.hcl`, `build.pkr.hcl`); changing
  the `vm_name` format breaks release tagging.
- The ISO comes from Debian `release/current/`: after a point release the pinned ISO disappears and builds
  fail until the check-debian-iso PR merges. When Debian 14 becomes current, `bootstrap.sh` fails the
  build on purpose until the i915 pair is bumped.
- The guest stays on the i915 `2026.03.05.x` line because Debian 13 runs kernel 6.12; the host runs a
  newer line on purpose. To move it, follow README "Moving the guest to a newer line".
- `scripts/i915_compat.py` exits 0 = metadata OK (hardware untested), 1 = incompatible or blocked,
  2 = unknown (fail-closed). Host 2026.09.16 is known-bad. Never loosen the fail-closed behaviour.
- `i915-compat.yml` must keep no `paths` filter (the test suite asserts it). Required checks are listed
  in `.github/required-status-checks.json`; `validate.yml`'s `paths-ignore` leaves README-only PRs
  without one (known, unfixed).
- Keep each `# renovate:` comment directly above the value it annotates.
- Packer is unpinned (`setup-packer version: latest`, `hashicorp/packer:light`, no `required_version`).

## Contracts

Changing a contract means changing both sides together; see `../CLAUDE.md`.

- Image manifest → terraform: `build.pkr.hcl` (`post-processor "manifest"`), `config.pkr.hcl`
  (`vm_name`), `.github/workflows/build.yml` (`push-manifest` job).
- Guest i915 pair → ansible: top-level `i915_sriov_version` / `i915_sriov_kernel_series` in
  `debian.auto.pkrvars.hcl`, regex-read from `main` (keep `key = "value"`, defined once).
- Host i915 pair ← ansible: read by `.github/workflows/i915-compat.yml`.
- `scripts/i915_compat.py` and its test stay byte-identical with ansible's copies.

## Git

Commit only in this repo. Never push or open PRs unless asked. Never commit secrets or a local
`packer-manifest.json`.

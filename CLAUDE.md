# packer

Builds three Debian 13 Proxmox VM templates (ADR 0017): base (VM ID 900, from the ISO), and k3s (901) and
storage (902), both cloned from the base. Every K3s node is cloned from the k3s template. Stage 1 of
packer → terraform → ansible → apps; the system overview is `../CLAUDE.md` (from the `.github` repo).

## What runs live

- **Every push to `main` is a real build** (`.github/workflows/build.yml`): the self-hosted runner builds the base
  first (`packer build -force -only=...`), then k3s and storage, replacing templates 900, 901 and 902. The k3s
  job publishes a GitHub release and opens a `packer-build-<run>` PR in `terraform` that merges the k3s
  entry into terraform's manifest by name (`scripts/merge-manifest.sh`). The storage build opens no PR:
  terraform clones template 902 by VM ID. Only
  `README.md` and `renovate.json` are path-ignored, so docs-only commits (including this file) need `[skip ci]`
  in the subject.
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
python3 scripts/tests/test_image_layout.py   # offline; pins the three-image layout
python3 scripts/tests/test_merge_manifest.py # offline; needs bash and jq
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

- `scripts/base.sh` migrates ifupdown → Netplan as its last network step; doing it before a download
  broke the download (f9f0b6d).
- `firmware-misc-nonfree` provides the i915 GuC/HuC blobs; without it there is no `renderD128` (#78).
- Driver 2026.05.03 failed DKMS (`BUILD_EXCLUSIVE` vs Debian kernel strings) and was reverted (#93).
- ModemManager is purged because it interferes with Zigbee USB serial adapters (#81).
- `seal.sh` runs last in every build and needs `skip_clean = true`: it deletes the user Packer is logged in as.
- The clone source sets only `ssh_username`, so the plugin injects an ephemeral key through cloud-init. It must
  repeat the hardware settings: `proxmox-clone` re-applies its own (defaults otherwise).
- `-force` deletes whatever VM holds 900, 901 or 902; confirm those IDs are free before a first build.
- The manifest `git_tag` is regex-derived from `vm_name` (`local.git_tag` in `config.pkr.hcl`); changing
  the `vm_name` format breaks release tagging.
- The ISO comes from Debian `release/current/`: after a point release the pinned ISO disappears and builds
  fail until the check-debian-iso PR merges. When Debian 14 becomes current, `k3s.sh` fails the
  build on purpose until the i915 pair is bumped.
- The guest stays on the i915 `2025.12.10.x` maintenance line because Debian 13 runs kernel 6.12
  (`2026.03.05.x` stopped building on 6.12.113+, upstream #502); the host runs a
  newer line on purpose. To move it, follow `docs/i915-sriov.md` "Moving the guest to a newer line".
- `k3s.sh` adds `i915.xelp_enable_ccs=1`: host PF `2026.09.14` runs Xe_LP CCS, guest `2025.12.10.1+`
  defaults it off, and the mismatch (VF PPGTT 48, no `ccs0`) hung `rcs0` under OpenCL and OpenVINO
  (2026-11-06). It assumes PF CCS on: re-decide it with any host or guest i915 bump, and test OpenCL too.
- `scripts/i915_compat.py` exits 0 = metadata OK (hardware untested), 1 = incompatible or blocked,
  2 = unknown (fail-closed). Host 2026.09.16 is known-bad. Never loosen the fail-closed behaviour.
- `i915-compat.yml` must keep no `paths` filter (the test suite asserts it). Required checks are listed
  in `.github/required-status-checks.json`; `validate.yml`'s `paths-ignore` leaves README-only PRs
  without one (known, unfixed).
- Keep each `# renovate:` comment directly above the value it annotates.
- Packer is unpinned (`setup-packer version: latest`, `hashicorp/packer:light`, no `required_version`).

## Contracts

Changing a contract means changing both sides together; see `../CLAUDE.md`.

- Image manifest → terraform: `build-*.pkr.hcl` (`post-processor "manifest"`, entry `name` = the build's
  source name `base`/`k3s`/`storage`), `config.pkr.hcl` (`vm_name`, `git_tag`), `.github/workflows/build.yml`
  (`push-manifest`) and `scripts/merge-manifest.sh` (the k3s entry stays at `builds[0]` until terraform
  selects by name).
- Guest i915 pair → ansible: top-level `i915_sriov_version` / `i915_sriov_kernel_series` in
  `debian.auto.pkrvars.hcl`, regex-read from `main` (keep `key = "value"`, defined once).
- Host i915 pair ← ansible: read by `.github/workflows/i915-compat.yml`.
- `scripts/i915_compat.py` and its test stay byte-identical with ansible's copies.

## Git

Commit only in this repo. Never push or open PRs unless asked. Never commit secrets or a local
`packer-manifest.json`.

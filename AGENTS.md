# Repository Guidelines

## Purpose and layout

Packer builds Debian VM templates on Proxmox for the sibling Terraform repository.
Read `README.md` and the relevant `.github/workflows/` files before changing the
image pipeline.

- `config.pkr.hcl`, `source.pkr.hcl`, `build.pkr.hcl`: plugins, VM source, provisioning, and manifest output.
- `variables.pkr.hcl`, `debian.auto.pkrvars.hcl`: inputs and image settings.
- `http/preseed.cfg.tmpl`: unattended Debian installation.
- `cloud-init/`: configuration copied into the image.
- `scripts/bootstrap.sh`, `scripts/delete_builder_user.sh`: image setup and cleanup.
- `scripts/i915_compat.py`, `scripts/tests/`: GPU compatibility policy and tests.

## Editing conventions

Use native HCL and existing provisioning scripts; format HCL with Packer.
Shell formatting uses `shfmt -i 2 -ci -s`. Preserve Renovate annotations.
Keep clone identity cleanup, cloud-init behavior, and builder-account removal
intact. Provisioning scripts execute inside a VM and are not local setup scripts.

GPU driver/kernel changes must be compatible with the Proxmox host configuration
in the sibling Ansible repository. Follow `i915-compat.yml`; do not bypass its
metadata or known-bad checks. Keep generated manifest fields consistent with the
Terraform consumer. Treat manifests as build outputs, not evidence of an unrun build.

## Validation

Run from the repository root:

```sh
packer fmt -check -recursive .
packer init .
PKR_VAR_proxmox_api_url=https://proxmox.example.com:8006/api2/json \
PKR_VAR_proxmox_api_token_id=id PKR_VAR_proxmox_api_token_secret=secret \
  packer validate .
python3 scripts/tests/test_i915_compat.py
shellcheck scripts/*.sh
```

`packer init` downloads plugins; validation uses the same placeholder inputs as
CI and does not build a VM. Use `pre-commit run --files <changed-files>` for the
configured hooks. Changes to compatibility policy also need the corresponding
workflow check against upstream metadata; offline tests alone do not establish
runtime GPU compatibility.

## Delivery

`packer build` creates infrastructure and the build workflow can open a downstream
Terraform manifest PR. Run builds only within the requested operational scope.
Keep API tokens and builder credentials out of commits and logs. Report what was
validated separately from anything actually built or tested on hardware.

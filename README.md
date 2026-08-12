<div align="center">

# 📦 Packer — Golden Image Factory

**Automated, immutable Debian VM template builds for Proxmox VE**

[![Packer](https://img.shields.io/badge/Packer-02A8EF?style=for-the-badge&logo=packer&logoColor=white)](https://www.packer.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian_Trixie-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org/)
[![HCL](https://img.shields.io/badge/HCL-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](#)

*The first stage of a fully automated infrastructure pipeline — from bare ISO to production-ready VM template*

</div>

---

## Table of Contents

- [Overview](#overview)
- [Build Pipeline](#build-pipeline)
- [What Gets Built](#what-gets-built)
- [Configuration](#configuration)
- [CI/CD Automation](#cicd-automation)
- [Cross-Repo Integration](#cross-repo-integration)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [License \& Contributing](#license--contributing)

---

## Overview

This repository produces **production-ready Debian VM templates** on Proxmox VE. Each template is a sealed, immutable "golden image" that includes:

- **Cloud-init** for zero-touch provisioning when cloned
- **Intel i915 SR-IOV DKMS driver** for GPU virtual function passthrough
- **Modern networking** (systemd-networkd + netplan) replacing legacy ifupdown
- **Hardened GRUB** with GPU and security parameters baked in
- **Clean machine identity** for unique clone provisioning

When a build completes, it automatically generates a manifest that triggers downstream Terraform provisioning — no manual steps required.

---

## Build Pipeline

Every template is built through a deterministic 4-stage pipeline:

```mermaid
flowchart LR
    subgraph preseed["Stage 1 · Preseed"]
        A([Debian ISO]) ==> B[Automated\nInstaller] ==> C[Base OS + SSH\n+ QEMU Agent]
    end

    subgraph bootstrap["Stage 2 · Bootstrap"]
        C ==> D[Package\nUpgrades] ==> E[SR-IOV\nDriver] ==> F[Netplan\nMigration] ==> G[GRUB\nHardening]
    end

    subgraph cloudinit["Stage 3 · Cloud-Init"]
        G ==> H[Datasource\nConfig] ==> I[Default User\nSetup] ==> J[Module\nOrdering]
    end

    subgraph finalize["Stage 4 · Finalize"]
        J ==> K[Remove\nBuild User] ==> L[(Seal as\nTemplate)] ==> M>Manifest JSON]
    end

    classDef input fill:#A81D33,stroke:#8B1728,color:#fff
    classDef store fill:#E57000,stroke:#CC6300,color:#fff
    classDef output fill:#02A8EF,stroke:#0196D4,color:#fff
    class A input
    class L store
    class M output
```

| Stage | Purpose | Key Actions |
|-------|---------|-------------|
| **Preseed** | Unattended Debian install from ISO | Locale, partitioning, base packages, temporary build user |
| **Bootstrap** | Post-install hardening & drivers | SR-IOV DKMS, netplan migration, GRUB params, firmware cleanup |
| **Cloud-Init** | Provisioning framework | Proxmox datasources, default user, module pipeline |
| **Finalize** | Seal & export | Remove build user, convert to template, emit manifest JSON |

---

## What Gets Built

The output is a Proxmox VM template with these properties:

| Property | Value |
|----------|-------|
| **Guest OS** | Debian Trixie (latest stable) |
| **Machine Type** | q35 (UEFI-ready) |
| **SCSI Controller** | virtio-scsi-pci |
| **Disk** | Thin-provisioned on ZFS with TRIM |
| **Network** | Virtio NIC with netplan/systemd-networkd |
| **GPU Support** | Intel i915 SR-IOV DKMS (GuC enabled, `xe` driver blacklisted) |
| **Provisioning** | Cloud-init (NoCloud + ConfigDrive datasources) |
| **Root Login** | Disabled — sudo-capable default user only |

---

## Configuration

Build parameters are organized across HCL variable files:

| File | Purpose |
|------|---------|
| `variables.pkr.hcl` | All variable declarations with defaults |
| `debian.auto.pkrvars.hcl` | ISO version pin (auto-updated by Renovate & CI) |
| `config.pkr.hcl` | Plugin versions and dynamic naming |
| `source.pkr.hcl` | Proxmox API, VM hardware, network config |
| `build.pkr.hcl` | Provisioner chain and manifest post-processor |

Key configurable parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `proxmox_node` | `pve` | Target Proxmox node |
| `vm_id` | `900` | Template VM ID |
| `disk_storage_pool` | `local-zfs` | ZFS pool for template disk |
| `cpu_type` | `host` | CPU passthrough mode |
| `cores` / `memory` | `1` / `1024` | Build-time resources (not runtime) |
| `timezone` | `US/Eastern` | System timezone |
| ISO version | *(auto-managed)* | Pinned in `debian.auto.pkrvars.hcl` |

> **Note:** Proxmox API credentials and runner IP are injected via CI secrets — never committed to the repo.

---

## CI/CD Automation

Five GitHub Actions workflows automate the full lifecycle:

```mermaid
flowchart TD
    subgraph pr["PR Phase"]
        PR([Pull Request]) --> V[validate.yml\nPacker init + validate]
        PR --> F[format.yml\npacker fmt · Prettier\nshfmt · shellcheck]
        PR --> DRV{{i915-compat.yml\nHost ↔ guest driver compatibility}}
    end

    subgraph merge["Merge Phase"]
        M([Merge to Main]) ==> B[build.yml\nBuild template\non Proxmox]
        B ==> REL>GitHub Release]
        B ==> TF>Terraform PR\nwith manifest]
    end

    subgraph sched["Scheduled"]
        CRON((Every\nFriday)) --> ISO[check-debian-iso.yml\nNew Debian release?]
        ISO -.->|New version| PR2>Auto-create PR]
    end

    classDef build fill:#02A8EF,stroke:#0196D4,color:#fff
    classDef dispatch fill:#7B42BC,stroke:#6A35A3,color:#fff
    classDef gate fill:#E57000,stroke:#CC6300,color:#fff
    class B build
    class TF dispatch
    class DRV gate
```

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **validate** | PR | Runs `packer init` + `packer validate` |
| **format** | PR | Enforces `packer fmt`, Prettier, shfmt, shellcheck |
| **i915-compat** | PR (driver/kernel config changes) | Blocks merge unless upstream data proves the guest ↔ host driver combination works |
| **build** | Push to main | Full build → GitHub Release → Terraform manifest PR |
| **check-debian-iso** | Weekly (Friday) | Scrapes debian.org for new ISO releases, auto-creates PR |

### i915 SR-IOV Driver Compatibility

The host (PF) and the guest (VF) **do not have to run the same
`i915-sriov-dkms` version** — upstream states this explicitly, and the releases
have split into kernel-specific lines:

| Side | Kernel | Driver line | Why |
|------|--------|-------------|-----|
| **Guest** (this repo) | 6.12 (Debian 13) | `2026.03.05.x` | The newest line requires kernel 6.17+; the backport line supports 6.12–6.19 |
| **Host** (Proxmox, ansible repo) | 6.17 (pinned) | `2026.08.12.x` | Supports 6.17–7.1 |

Three independent axes must hold, and all three come from upstream data for the
exact release tags — never from version ordering or a curated allowlist:

1. **guest driver ↔ guest kernel** — the release notes of the exact tag must
   cover `i915_sriov_kernel_series`
2. **host driver ↔ host kernel** — same check against the pinned Proxmox kernel
3. **PF ↔ VF IOV ABI** — `IOV_VERSION_{BASE,LATEST}_{MAJOR,MINOR}` from each
   tag's `gt/iov/abi/iov_version_abi.h`, replayed through the upstream
   handshake to see whether a common ABI can be negotiated

`scripts/i915_compat.py` implements all three (stdlib only, no dependencies)
and is shared verbatim with the ansible repo. **Unknown means fail**: a missing
tag, unparsable release notes, a missing ABI header or a network failure all
exit non-zero rather than approving an unverified combination.

```console
$ python3 scripts/i915_compat.py \
    --host-version 2026.08.12.1 --host-kernel 6.17.13-13-pve \
    --guest-version 2026.03.05.6 --guest-kernel 6.12
# exit 0 = compatible · 1 = incompatible · 2 = cannot be established
```

Two layers protect the image build:

1. **CI** (`i915-compat.yml`) validates the declared guest driver + kernel
   series against the host state on the ansible repo's `main`, and posts the
   report as a sticky PR comment.
2. **Build** (`scripts/bootstrap.sh`) re-checks the kernel the image *actually*
   has (running plus every installed `/lib/modules` kernel) against
   `i915_sriov_kernel_series` before installing the DKMS package, so a Debian
   kernel bump fails the build instead of shipping a broken template.

Renovate may only propose releases on the `2026.03.05.x` line
(`allowedVersions` in `renovate.json`), and its PRs still have to pass
`i915-compat` — a newer version number alone can never merge.

**Moving the guest to a newer line** (e.g. when Debian ships a 6.17+ kernel):
update `i915_sriov_version` and `i915_sriov_kernel_series` in
`debian.auto.pkrvars.hcl`, widen `allowedVersions` in `renovate.json`, and let
`i915-compat` confirm the new pair.

---

## Cross-Repo Integration

This repo is the **entry point** of a 4-stage infrastructure pipeline:

```mermaid
flowchart LR
    P(["📦 Packer\nBuild Template"]) ==>|"manifest PR"| T(["🏗️ Terraform\nProvision VMs"])
    T ==>|"repository dispatch"| A(["⚙️ Ansible\nConfigure Cluster"])
    A ==>|"App-of-Apps"| K(["☸️ Apps\nDeploy Services"])

    classDef packer fill:#02A8EF,stroke:#0196D4,color:#fff
    classDef terraform fill:#7B42BC,stroke:#6A35A3,color:#fff
    classDef ansible fill:#EE0000,stroke:#CC0000,color:#fff
    classDef apps fill:#326CE5,stroke:#2B5FC2,color:#fff
    class P packer
    class T terraform
    class A ansible
    class K apps
```

1. **Packer** builds a template and generates `packer-manifest.json`
2. The build workflow **creates a PR in the Terraform repo** with the updated manifest
3. Terraform clones the new template into cluster VMs
4. Terraform triggers Ansible via `repository_dispatch`
5. Ansible provisions K3s and bootstraps ArgoCD
6. ArgoCD reconciles the Apps repo onto the cluster

---

## Prerequisites

- **Proxmox VE** with API token access (VM.Allocate, VM.Clone, VM.Config.\*, Datastore.\*, Sys.Modify)
- **Storage pools**: ISO storage (`local`) + ZFS disk pool (`local-zfs`)
- **Network**: HTTP port 8000 accessible from Proxmox to the build runner (preseed serving)
- **Packer** ≥ 1.10 with the `hashicorp/proxmox` plugin

---

## Usage

```bash
# Initialize plugins
packer init -upgrade .

# Validate configuration
packer validate .

# Build the template (requires Proxmox credentials)
packer build -force .
```

> In practice, builds are triggered automatically via CI on merge to `main`.

---

## License & Contributing

This is a personal homelab project. Feel free to use it as inspiration for your own infrastructure. If you spot an issue or have a suggestion, [open an issue](../../issues) — contributions and feedback are welcome.

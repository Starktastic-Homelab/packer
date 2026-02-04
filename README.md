# homelab-packer

Packer templates for building Debian VM images on Proxmox VE. This repository automates the creation of cloud-init ready VM templates optimized for Kubernetes nodes with Intel SR-IOV GPU passthrough support.

## Features

- **Debian 13 (Trixie)** base image with automated preseed installation
- **Cloud-init integration** for dynamic VM configuration at deploy time
- **Intel SR-IOV DKMS driver** pre-installed for GPU passthrough
- **Netplan networking** with systemd-networkd and systemd-resolved
- **Automated CI/CD** with GitHub Actions for building, validating, and ISO updates
- **Renovate integration** for dependency and plugin updates

## Prerequisites

### Proxmox VE Setup

1. **API Token**: Create a Proxmox API token with the following permissions:
   - `VM.Allocate`
   - `VM.Clone`
   - `VM.Config.*`
   - `VM.Audit`
   - `VM.PowerMgmt`
   - `Datastore.AllocateSpace`
   - `Datastore.Audit`
   - `Sys.Modify` (for ISO operations)

2. **Storage Pools**: Ensure you have:
   - An ISO storage pool (default: `local`)
   - A disk storage pool (default: `local-zfs`)

3. **Network**: A bridge interface configured (default: `vmbr0`)

### Local Development

- [Packer](https://www.packer.io/downloads) 1.10+
- Network access to your Proxmox host
- HTTP port 8000 accessible from Proxmox to the build machine

## Repository Structure

```
.
├── .github/workflows/     # CI/CD workflows
│   ├── build.yml          # Main build pipeline
│   ├── check-debian-iso.yml # Automated ISO updates
│   ├── format.yml         # Code formatting
│   └── validate.yml       # PR validation
├── cloud-init/            # Cloud-init configuration
│   ├── cloud.cfg          # Main cloud-init config
│   └── cloud.cfg.d/
│       └── 99-pve.cfg     # Proxmox datasource config
├── http/
│   └── preseed.cfg.tmpl   # Debian preseed template
├── scripts/
│   ├── bootstrap.sh       # VM provisioning script
│   └── delete_builder_user.sh # Security cleanup
├── build.pkr.hcl          # Build definition
├── config.pkr.hcl         # Plugin requirements and locals
├── source.pkr.hcl         # Proxmox source configuration
├── variables.pkr.hcl      # Variable definitions
├── debian.auto.pkrvars.hcl # ISO version (auto-loaded)
└── renovate.json          # Dependency update config
```

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_api_url` | Proxmox API URL (e.g., `https://pve:8006/api2/json`) | **Required** |
| `proxmox_api_token_id` | API token ID (e.g., `user@pam!token`) | **Required** |
| `proxmox_api_token_secret` | API token secret | **Required** |
| `proxmox_node` | Proxmox node name | `pve` |
| `insecure_skip_tls_verify` | Skip TLS verification (for self-signed certs) | `false` |
| `vm_id` | Template VM ID | `900` |
| `iso_name` | Debian ISO filename | **Required** |
| `iso_base_url` | Base URL for ISO downloads | `https://get.debian.org/images/release/current/amd64/iso-cd` |
| `iso_storage_pool` | Proxmox storage for ISOs | `local` |
| `disk_storage_pool` | Proxmox storage for VM disks | `local-zfs` |
| `network_adapter_bridge` | Network bridge | `vmbr0` |
| `runner_host_ip` | IP of the Packer host (for preseed HTTP) | `127.0.0.1` |
| `timezone` | VM timezone | `US/Eastern` |
| `builder_creds` | Temporary build user credentials | `{ username = "packer", password = "packer" }` |
| `apt_mirror` | APT mirror configuration | US Debian mirror |

### Local Build

1. Create a variables file:

```hcl
# my.pkrvars.hcl
proxmox_api_url          = "https://pve.local:8006/api2/json"
proxmox_api_token_id     = "packer@pve!packer-token"
proxmox_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_node             = "pve"
runner_host_ip           = "192.168.1.100"
insecure_skip_tls_verify = true  # Only if using self-signed certs
```

2. Initialize and build:

```bash
packer init .
packer build -var-file=my.pkrvars.hcl .
```

## GitHub Actions

### Required Secrets

| Secret | Description |
|--------|-------------|
| `PACKER_GITHUB_API_TOKEN` | GitHub token for downloading Packer plugins |
| `PACKER_RUNNER_HOST_IP` | IP address of the self-hosted runner |
| `PROXMOX_API_TOKEN_ID` | Proxmox API token ID |
| `PROXMOX_API_TOKEN_SECRET` | Proxmox API token secret |
| `ORG_DISPATCH_TOKEN` | Token for cross-repo dispatch (Terraform updates) |

### Required Variables

| Variable | Description |
|----------|-------------|
| `PROXMOX_API_URL` | Proxmox API URL |
| `TIMEZONE` | VM timezone |
| `APT_MIRROR_PROTOCOL` | `http` or `https` |
| `APT_MIRROR_COUNTRY` | `manual` for explicit mirror |
| `APT_MIRROR_HOSTNAME` | Mirror hostname |
| `APT_MIRROR_DIRECTORY` | Mirror path (e.g., `/debian`) |
| `INSECURE_SKIP_TLS_VERIFY` | Set to `true` for self-signed certs |

### Workflows

- **Build** (`build.yml`): Triggered on push to `main`. Builds the template, creates a GitHub release, and updates the Terraform repository with the new manifest.

- **Validate** (`validate.yml`): Runs `packer validate` on pull requests to catch configuration errors before merge.

- **Format** (`format.yml`): Auto-formats Packer HCL, YAML, JSON, and shell scripts on pull requests.

- **Check Debian ISO** (`check-debian-iso.yml`): Weekly check for new Debian releases, automatically creates PRs to update the ISO version.

## What Gets Built

The resulting VM template includes:

- **Debian 13 (Trixie)** minimal installation
- **Cloud-init** configured with Proxmox datasource
- **Netplan** with systemd-networkd/resolved
- **Intel SR-IOV DKMS driver** for GPU passthrough
- **GRUB** configured with `i915.enable_guc=3` and `module_blacklist=xe`
- **Clean machine ID** for proper clone uniqueness
- **No default users** (builder user is removed post-build)

## Related Repositories

- [homelab-terraform](../homelab-terraform) - Terraform configurations that consume these templates
- [homelab-ansible](../homelab-ansible) - Ansible playbooks for post-deployment configuration
- [homelab-platform](../homelab-platform) - Kubernetes platform applications

## License

MIT

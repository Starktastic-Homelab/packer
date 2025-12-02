# 📦 Homelab Packer: Debian Cloud-Init Template

   

This repository automates the creation of a "Golden Image" for **Proxmox VE** using HashiCorp Packer.

It builds a **Debian** VM template designed specifically as a base for Kubernetes (K3s) nodes. It features a modernized networking stack, storage optimizations, and a fully automated GitOps supply chain.

## ✨ Key Features

  * **Modern Networking (Netplan):** The legacy `ifupdown` system is purged. The image uses `netplan.io` backed by `systemd-networkd` and `systemd-resolved`. This resolves common Cloud-Init race conditions and DNS issues on Proxmox.
  * **Kubernetes Ready:**
      * **Unique Identity:** Automatically resets `/etc/machine-id` on build. This ensures cloned nodes get unique DHCP leases and K3s Node IDs.
      * **Dependencies:** Pre-installed with `open-iscsi`, `nfs-common`, and `qemu-guest-agent`.
      * **Cloud-Native:** Configured with the `NoCloud` datasource for seamless Proxmox Cloud-Init integration.
  * **Storage Optimized:** Disk is configured with `discard=true` (TRIM) enabled, ensuring the template remains small and cloned VMs utilize storage efficiently.
  * **Automated Supply Chain:**
      * **Weekly Checks:** A workflow monitors Debian mirrors for new ISO releases.
      * **Auto-Updates:** If a new ISO is found, a PR is auto-generated.
      * **Downstream Integration:** Upon a successful build, the pipeline pushes the new artifact manifest directly to the [Homelab Terraform Repository](https://github.com/MrStarktastic/homelab-terraform).

## 📂 Repository Structure

```text
.
├── build.pkr.hcl            # Main build definition (Provisioners & Post-Processors)
├── source.pkr.hcl           # VM hardware specs (VirtIO, Cloud-Init, Discard enabled)
├── config.pkr.hcl           # Plugin configuration (HashiCorp Proxmox)
├── variables.pkr.hcl        # Input variables definition
├── debian.auto.pkrvars.hcl  # Variable overrides (ISO Version)
├── scripts/
│   ├── bootstrap.sh         # The "Magic": Installs Netplan, resets IDs, hardens OS
│   └── delete_builder_user.sh
├── cloud-init/              # Cloud-Init config (NoCloud datasource)
├── http/                    # Preseed configuration for unattended install
└── .github/workflows/       # CI/CD Pipelines
```

## 🛠️ Prerequisites

  * **Proxmox VE** (7.x or 8.x)
  * **Packer** (v1.10+)
  * **Proxmox API Token** (User must have permissions to Datastore, VM.Allocate, VM.Console)

## 🚀 Usage

### 1\. Configure Credentials

You can provide credentials via environment variables or a `secrets.auto.pkrvars.hcl` file (git-ignored):

```bash
export PKR_VAR_proxmox_api_url="https://pve.example.com:8006/api2/json"
export PKR_VAR_proxmox_api_token_id="packer@pve!token"
export PKR_VAR_proxmox_api_token_secret="your-uuid-secret"
```

### 2\. Build Manually

```bash
# Initialize plugins
packer init .

# Validate configuration
packer validate .

# Run the build
packer build .
```

## ⚙️ Configuration Deep Dive

### The Bootstrapper (`scripts/bootstrap.sh`)

This script runs during the Packer build to transform a standard Debian install into a Cloud-Native template:

1.  **Installs Core Deps:** `curl`, `cloud-init`, `netplan.io`, `systemd-resolved`, `open-iscsi`.
2.  **Purges Legacy Network:** Removes `ifupdown` to force Cloud-Init to render Netplan YAML.
3.  **Links DNS:** Symlinks `/etc/resolv.conf` to `systemd-resolved`'s stub listener.
4.  **Resets Machine ID:** Truncates `/etc/machine-id` to ensure uniqueness on cloning.

### CI/CD Workflow

1.  **Check ISO (`check-debian-iso.yml`):** Runs weekly. Scrapes Debian.org. If `debian.auto.pkrvars.hcl` is outdated, it updates the file and creates a PR.
2.  **Build & Push (`build.yml`):**
      * Runs on a **Self-Hosted Runner** (inside the homelab).
      * Builds the VM template.
      * Generates a `packer-manifest.json`.
      * **Triggers Downstream:** Clones the `homelab-terraform` repo, updates the manifest file there, and opens a PR to deploy the new image.

## 🔗 Related Repositories

  * **Infrastructure:** [MrStarktastic/homelab-terraform](https://github.com/MrStarktastic/homelab-terraform) - Consumes the manifest produced by this repo to provision the cluster.

## 📄 License

This project is licensed under the MIT License.
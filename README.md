# Homelab Packer

This repository builds a customized Debian-based Proxmox VM template using [HashiCorp Packer](https://www.packer.io/) for use in a self-hosted homelab environment.

The resulting image includes Proxmox-compatible configurations and is designed to be consumed by a Terraform-based infrastructure managed in a separate repository ([MrStarktastic/homelab-terraform](https://github.com/MrStarktastic/homelab-terraform)).

---

## 📦 Overview

### Project Structure

```
.
├── build.pkr.hcl                 # Entry point for Packer build
├── config.pkr.hcl                # Plugin and builder configuration
├── source.pkr.hcl                # Source configuration (VM definition)
├── variables.pkr.hcl             # Default and required Packer variables
├── debian.auto.pkrvars.hcl       # Auto-loaded user variable overrides
├── cloud-init/                  # Cloud-init configuration files
│   ├── cloud.cfg
│   └── cloud.cfg.d/
│       └── 99-pve.cfg
├── http/
│   └── preseed.cfg.tmpl         # Preseed template for Debian installation
├── scripts/                     # Lifecycle and bootstrap scripts
│   ├── bootstrap.sh
│   └── delete_builder_user.sh
├── .github/
│   └── workflows/               # GitHub Actions workflows
│       ├── build.yml
│       ├── check-debian-iso.yml
│       ├── format.yml
│       └── validate.yml
├── renovate.json                # Renovate configuration for automation
└── README.md
```

---

## 🚀 Packer Template Flow

1. **`build.pkr.hcl`** – Main file tying together variables, source, and post-processors.
2. **`source.pkr.hcl`** – Defines how the base Debian image is downloaded and configured.
3. **`http/preseed.cfg.tmpl`** – Used during boot to automate Debian installation via preseeding.
4. **`cloud-init/`** – Injected post-install to configure the VM for Proxmox cloud-init compatibility.
5. **`scripts/bootstrap.sh`** – Installs SSH keys and packages.
6. **`scripts/delete_builder_user.sh`** – Removes the temporary user created during provisioning.

---

## 🔧 GitHub Actions

This repository includes automated CI workflows to:

- Validate packer templates (`validate.yml`)
- Auto-format code (`format.yml`)
- Build and upload images (`build.yml`)
- Check for new Debian ISO versions and open PRs (`check-debian-iso.yml`)

---

## 🔐 Authentication: API Token Setup

To run Packer locally or in CI, you must supply a Proxmox API token via environment variables or Packer variables.

### Required Packer variables

These variables must be passed in as environment variables or using `-var`/`-var-file`:

```hcl
variable "proxmox_api_url" {}
variable "proxmox_api_token_id" {}
variable "proxmox_api_token_secret" {}
```

### Using Environment Variables

```bash
export PKR_VAR_proxmox_api_url="https://proxmox.example.com:8006/api2/json"
export PKR_VAR_proxmox_api_token_id="user@pam!token"
export PKR_VAR_proxmox_api_token_secret="secret"
```

Alternatively, use a `.auto.pkrvars.hcl` file (e.g., `debian.auto.pkrvars.hcl`) to define and override values locally.

---

## 🧠 Debian ISO Auto-Updater

The `check-debian-iso.yml` GitHub Actions workflow checks for new ISO releases at `https://get.debian.org/images/release/current/amd64/iso-cd/` and creates a pull request to update the `iso_name` variable automatically when a new version is found.

---

## ♻️ Dependency Automation

[Renovate](https://docs.renovatebot.com/) is configured to:

- Monitor GitHub Actions workflows
- Detect updates to Packer plugins
- Propose PRs for plugin and dependency version updates

---

## 📎 Related Repositories

- **Terraform Integration**: [`MrStarktastic/homelab-terraform`](https://github.com/MrStarktastic/homelab-terraform) – Uses the built image to spin up k3s clusters and infrastructure.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

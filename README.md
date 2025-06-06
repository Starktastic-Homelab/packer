# homelab-packer

**Automated Packer builds for Proxmox QEMU VM templates (Debian-based), enabling immutable, GitOps-friendly VM deployment and cloud-init integration.**

---

## 📦 Overview

This repository contains everything you need to produce automated, repeatable, and minimal **Debian cloud-init VM templates** for your Proxmox environment.  
It supports headless, API-driven image builds and integrates seamlessly with CI (GitHub Actions + self-hosted runners), as well as local builds.

### Key Features

- **Packer QEMU/Proxmox builder** (`proxmox-iso`)
- **Automated Debian ISO version checks** (GitHub Actions workflow)
- **Strictly declarative config via `.auto.pkrvars.hcl`**
- **Cloud-init ready templates** (for hands-free VM provisioning)
- **Provisioners for minimal, hardened base OS**
- **CI workflows for format, validate, build**

---

## 🚀 Usage

### 1. **Clone the repository**

```sh
git clone https://github.com/MrStarktastic/homelab-packer.git
cd homelab-packer
```

### 2. **Prepare Environment Variables**

- **You must set** these (see “Authentication” below):
  - `PKR_VAR_proxmox_api_url`
  - `PKR_VAR_proxmox_api_token_id`
  - `PKR_VAR_proxmox_api_token_secret`
- Example:
  ```sh
  export PKR_VAR_proxmox_api_url="https://proxmox.example.com:8006/api2/json"
  export PKR_VAR_proxmox_api_token_id="root@pam!packer"
  export PKR_VAR_proxmox_api_token_secret="your-token-secret"
  ```

### 3. **Build a Template Locally**

```sh
packer init .
packer build -var-file=debian.auto.pkrvars.hcl .
```

### 4. **Automated Build via GitHub Actions**

- This repository is set up to:
  - **Validate and format** Packer files on pull requests.
  - **Build and test** templates on merge to `main` (runs on a self-hosted runner, e.g. Raspberry Pi).
  - **Auto-bump** the Debian ISO when a new release is detected.

---

## 🔄 Automated Debian ISO Update

A scheduled GitHub Actions workflow checks the official Debian release directory weekly.  
If a new ISO is available, it:
- Updates `debian.auto.pkrvars.hcl`
- Creates a pull request with the new version and a helpful comment

---

## 🤖 Automation & CI

- **`validate-and-format.yml`**: Checks formatting and syntax on all PRs.
- **`build.yml`**: Builds and tests templates on push to main (self-hosted runner).
- **`check-debian-iso.yml`**: Weekly Debian ISO version check and PR creation.

---

## 🧩 Integrations

- **Renovate**: Handles plugin and GitHub Actions workflow updates.
- **MinIO / S3** (optional): Can be used for artifact storage if scaling up CI/CD.

---

## 🛡️ Authentication: API Token Setup

To allow Packer to build templates in Proxmox, you must set up an API token:

1. **Create an API token** under your root user (or a service user) in Proxmox.
2. **Assign a custom role** with the following privileges:  
   ```
   Datastore.AllocateSpace Datastore.AllocateTemplate SDN.Use Sys.Modify
   VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit
   VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options
   VM.Console VM.Monitor VM.PowerMgmt
   ```
3. **Export these as environment variables:**
   - `PKR_VAR_proxmox_api_url`
   - `PKR_VAR_proxmox_api_token_id`
   - `PKR_VAR_proxmox_api_token_secret`

> For more details, see the Proxmox API token documentation.

---

## 💬 Support & Contributions

- **Issues and PRs are welcome!**  
- Please use descriptive commit messages and keep code minimal and reproducible.

---

## 📜 License

This repository is [MIT licensed](LICENSE).

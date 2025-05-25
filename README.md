# homelab-packer

Minimal, secure, and reproducible [Packer](https://www.packer.io/) build pipeline for creating **cloud-init–ready Debian 12 templates on Proxmox VE**.

---

## 💡 Overview

This repository uses the `proxmox-iso` builder plugin to fully automate the process of:

- Downloading a Debian 12 ISO
- Uploading the ISO to your Proxmox node
- Installing a minimal, hardened Debian 12 image
- Enabling `cloud-init` and the `qemu-guest-agent`
- Cleaning up provisioning user and setting sane defaults
- Producing a template-ready VM with passwordless sudo for cloud-init users

---

## ⚙️ Requirements

- Proxmox VE 7 or 8
- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.8
- [Proxmox Packer plugin](https://github.com/hashicorp/packer-plugin-proxmox)
- Internet access to fetch ISO and Packer plugin
- Proxmox Virtual Environment node

---

## 🔐 Authentication: API Token Setup

This project uses **Proxmox API tokens** instead of root password login. You must set up a token in Proxmox and provide credentials via environment variables.

### ✅ 1. Create a Proxmox API token

In your Proxmox UI:

1. Go to **Datacenter → Permissions → API Tokens**
2. Click **Add**:
   - **User**: `root@pam`
   - **Token ID**: `provisioner`
   - Disable **"Privilege Separation"** (makes it possible to use with Terraform)
3. Assign a role to the token under **Datacenter → Permissions** with the following privileges:

```text
Datastore.AllocateSpace
Datastore.AllocateTemplate
SDN.Use
Sys.Modify
VM.Allocate
VM.Audit
VM.Clone
VM.Config.CDROM
VM.Config.CPU
VM.Config.Cloudinit
VM.Config.Disk
VM.Config.HWType
VM.Config.Memory
VM.Config.Network
VM.Config.Options
VM.Console
VM.Monitor
VM.PowerMgmt
```

Apply this role to path `/`.

The role be created with the following command:
```bash
pveum roleadd ProvisionerRole -privs \
  "Datastore.AllocateSpace,Datastore.AllocateTemplate,SDN.Use,Sys.Modify,\
VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,\
VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,\
VM.Console,VM.Monitor,VM.PowerMgmt"
```

---

### ✅ 2. Set environment variables

Export the following **before running `packer build`**:

```bash
export PKR_VAR_proxmox_api_url=https://your-proxmox-host:8006/api2/json
export PKR_VAR_proxmox_api_token_id=root@pam!packer
export PKR_VAR_proxmox_api_token_secret=your_generated_token_secret
```

---

## 🚀 Usage

```bash
packer init .
packer build .
```

---

## 🧼 Hardening and Cleanup

At the end of the Packer build:

- The `packer` user is removed
- Its home directory and SSH keys are deleted
- Any `sudoers.d` entries for `packer` are cleared

---

## 🧪 Tested With

- Proxmox VE 8.4.1
- Packer 1.12
- Debian 12.11.0 ISO (netinst)

---

## 📄 License

MIT — free to use, modify, and adapt for your homelab or enterprise cluster.

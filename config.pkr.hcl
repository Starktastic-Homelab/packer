packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "v1.2.4"
    }
  }
}

locals {
  debian = regex("debian-\\d+\\.\\d+\\.\\d+", var.iso_name)
  stamp  = formatdate("YYYYMMDDhhmmss", timestamp())
  # The one list of templates: role => VM ID.
  templates = { base = var.base_vm_id, k3s = var.k3s_vm_id, storage = var.storage_vm_id }
  vm_name   = { for role, _ in local.templates : role => "${var.vm_name_prefix}-${role}-${local.debian}-${local.stamp}" }
  # The release tag: v<debian version>.<stamp>, read from the template name.
  git_tag = { for role, name in local.vm_name : role => "v${join(".", regex("(\\d+\\.\\d+\\.\\d+)-(\\d+)", name))}" }
}

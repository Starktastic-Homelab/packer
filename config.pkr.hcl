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
  # The manifest git_tag regex-reads "<debian>-<stamp>" from these names.
  vm_name = { for role in ["base", "k3s", "storage"] : role => "${var.vm_name_prefix}-${role}-${local.debian}-${local.stamp}" }
}

packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "v1.2.3"
    }
  }
}

locals {
  vm_name = "packer-${regex("debian-\\d+\\.\\d+\\.\\d+", var.iso_name)}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
}

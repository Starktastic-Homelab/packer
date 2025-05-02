packer {
  required_plugins {
    name = {
      version = "v1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

locals {
  vm_name = "packer-${regex("debian-\\d+\\.\\d+\\.\\d+", var.iso_name)}-${uuidv4()}"
}

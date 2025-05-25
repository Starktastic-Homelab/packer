variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  default = "pve"
}

variable "vm_id" {
  default = 900
}

variable "iso_base_url" {
  default = "https://get.debian.org/images/release/current/amd64/iso-cd"
}

variable "iso_name" {
  default = "debian-12.11.0-amd64-netinst.iso"
}

variable "iso_storage_pool" {
  default = "local"
}

variable "scsi_controller" {
  default = "virtio-scsi-pci"
}

variable "cpu_type" {
  default = "host"
}

variable "cores" {
  default = 1
}

variable "memory" {
  default = 1024
}

variable "disk_storage_pool" {
  #default = "local-zfs"
  default = "local-lvm" # TEMPORARY
}

variable "network_adapter_bridge" {
  default = "vmbr0"
}

variable "builder_creds" {
  default = {
    username = "packer"
    password = "packer"
  }
}

variable "timezone" {
  default = "US/Eastern"
}

variable "apt_mirror" {
  type = object({
    protocol  = string
    country   = string
    hostname  = string
    directory = string
  })
  default = {
    protocol  = "http"
    country   = "manual"
    hostname  = "http.us.debian.org"
    directory = "/debian"
  }
}

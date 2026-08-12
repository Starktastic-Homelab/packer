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

variable "insecure_skip_tls_verify" {
  description = "Skip TLS verification for Proxmox API. Set to true only for self-signed certificates."
  type        = bool
  default     = false
}

variable "vm_id" {
  default = 900
}

variable "iso_base_url" {
  default = "https://get.debian.org/images/release/current/amd64/iso-cd"
}

variable "iso_name" {
  description = "Name of the Debian ISO to use for the build (debian-X.Y.Z-amd64-netinst.iso)"
  type        = string

  validation {
    condition     = can(regex("^debian-[0-9]+\\.[0-9]+\\.[0-9]+-amd64-netinst\\.iso$", var.iso_name))
    error_message = "The iso_name must match the pattern 'debian-X.Y.Z-amd64-netinst.iso'."
  }
}

variable "iso_storage_pool" {
  default = "local"
}

variable "i915_sriov_version" {
  description = "i915-sriov-dkms release installed in the guest image. Must support i915_sriov_kernel_series upstream."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)+$", var.i915_sriov_version))
    error_message = "The i915_sriov_version must be an upstream release tag such as '2026.03.05.6'."
  }
}

variable "i915_sriov_kernel_series" {
  description = "Kernel major.minor series the guest image is expected to run (e.g. 6.12 for Debian 13)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.i915_sriov_kernel_series))
    error_message = "The i915_sriov_kernel_series must be a major.minor version such as '6.12'."
  }
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
  default = "local-zfs"
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

variable "runner_host_ip" {
  description = "The IP address of the Packer runner host, used to serve HTTP content during the build."
  default     = "127.0.0.1"
}

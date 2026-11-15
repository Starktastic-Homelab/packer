source "proxmox-clone" "storage" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  task_timeout             = "10m"

  clone_vm_id             = var.base_vm_id
  vm_id                   = var.storage_vm_id
  vm_name                 = local.vm_name.storage
  template_description    = "Debian 13 storage template - ${formatdate("YYYY-MM-DD.hh:mm:ss.ZZZ", timestamp())}"
  os                      = "l26"
  scsi_controller         = var.scsi_controller
  cpu_type                = var.cpu_type
  cores                   = var.cores
  memory                  = var.memory
  machine                 = "q35"
  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.disk_storage_pool

  # Username only: the plugin injects an ephemeral key through cloud-init.
  ssh_username = var.builder_creds.username
  ssh_timeout  = "10m"

  ipconfig {
    ip = "dhcp"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.network_adapter_bridge
  }
}

source "proxmox-iso" "debian-13" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  vm_id                   = var.vm_id
  vm_name                 = local.vm_name
  template_description    = "Debian 13 Template - ${formatdate("YYYY-MM-DD.hh:mm:ss.ZZZ", timestamp())}"
  os                      = "l26"
  scsi_controller         = var.scsi_controller
  cpu_type                = var.cpu_type
  cores                   = var.cores
  memory                  = var.memory
  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.disk_storage_pool

  ssh_username = var.builder_creds.username
  ssh_password = var.builder_creds.password
  ssh_timeout  = "10m"

  http_port_min = 8000
  http_port_max = 8000
  boot_command = [format("<esc><wait>auto url=http://%s:{{ .HTTPPort }}/preseed.cfg<enter>", var.runner_host_ip)]
  http_content = {
    "/preseed.cfg" = templatefile(
      "http/preseed.cfg.tmpl",
      {
        username             = var.builder_creds.username,
        password             = var.builder_creds.password,
        timezone             = var.timezone
        apt_mirror_protocol  = var.apt_mirror.protocol
        apt_mirror_country   = var.apt_mirror.country
        apt_mirror_hostname  = var.apt_mirror.hostname
        apt_mirror_directory = var.apt_mirror.directory
      }
    )
  }

  boot_iso {
    iso_url          = "${var.iso_base_url}/${var.iso_name}"
    iso_checksum     = "file:${var.iso_base_url}/SHA256SUMS"
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  disks {
    type         = "virtio"
    disk_size    = "4G"
    storage_pool = var.disk_storage_pool
    discard      = true
  }

  network_adapters {
    model  = "virtio"
    bridge = var.network_adapter_bridge
  }
}

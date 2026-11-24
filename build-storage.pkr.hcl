build {
  source "source.proxmox-clone.clone" {
    name                 = "storage"
    vm_id                = var.storage_vm_id
    vm_name              = local.vm_name.storage
    template_description = "Debian 13 storage template - ${formatdate("YYYY-MM-DD.hh:mm:ss.ZZZ", timestamp())}"
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/storage.sh"
  }

  # Runs last: it deletes the user Packer is logged in as.
  provisioner "shell" {
    skip_clean      = true
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}; rm -f {{ .Path }}"
    env = {
      BUILDER_USER = var.builder_creds.username
      CLONE_BUILD  = "1"
    }
    script = "scripts/seal.sh"
  }

  post-processor "manifest" {
    custom_data = {
      vm_name = local.vm_name.storage
      git_tag = local.git_tag.storage
      role    = source.name
    }
  }
}

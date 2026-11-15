build {
  sources = ["source.proxmox-clone.storage"]

  provisioner "file" {
    destination = "/tmp"
    source      = "files/storage/rtslib-fb-targetctl.service.d"
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
      git_tag = "v${join(".", regex("(\\d+\\.\\d+\\.\\d+)-(\\d+)", local.vm_name.storage))}"
    }
  }
}

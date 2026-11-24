build {
  sources = ["source.proxmox-iso.base"]

  provisioner "shell" {
    expect_disconnect = true
    execute_command   = "echo '${var.builder_creds.password}' | sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    script            = "scripts/base.sh"
  }

  provisioner "file" {
    destination = "/tmp"
    source      = "cloud-init"
  }

  provisioner "shell" {
    inline = [
      "echo '${var.builder_creds.password}' | sudo -S cp -rf /tmp/cloud-init/* /etc/cloud/",
      "rm -rf /tmp/cloud-init"
    ]
  }

  # Runs last: it deletes the user Packer is logged in as.
  provisioner "shell" {
    skip_clean      = true
    execute_command = "chmod +x {{ .Path }}; echo '${var.builder_creds.password}' | sudo -S env {{ .Vars }} {{ .Path }}; rm -f {{ .Path }}"
    env = {
      BUILDER_USER = var.builder_creds.username
    }
    script = "scripts/seal.sh"
  }

  post-processor "manifest" {
    custom_data = {
      vm_name = local.vm_name.base
      git_tag = local.git_tag.base
    }
  }
}

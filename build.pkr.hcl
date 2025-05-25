build {
  sources = ["source.proxmox-iso.debian-12"]

  provisioner "shell" {
    expect_disconnect = true
    execute_command   = "echo '${var.builder_creds.password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script            = "scripts/bootstrap.sh"
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

  provisioner "shell" {
    skip_clean      = true
    execute_command = "chmod +x {{ .Path }}; echo '${var.builder_creds.password}' | sudo -S env {{ .Vars }} {{ .Path }}; rm -f {{ .Path }}"
    env = {
      BUILDER_USER = var.builder_creds.username
    }
    script = "scripts/delete_builder_user.sh"
  }

  post-processor "manifest" {
    custom_data = {
      vm_name = local.vm_name
      git_tag = "v${join(".", regex("(\\d+\\.\\d+\\.\\d+)-(\\d+)", local.vm_name))}"
    }
  }
}

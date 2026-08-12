build {
  sources = ["source.proxmox-iso.debian-13"]

  provisioner "shell" {
    expect_disconnect = true
    execute_command   = "echo '${var.builder_creds.password}' | sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    script            = "scripts/bootstrap.sh"
    env = {
      I915_SRIOV_VERSION       = var.i915_sriov_version
      I915_SRIOV_KERNEL_SERIES = var.i915_sriov_kernel_series
    }
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
      vm_name                  = local.vm_name
      git_tag                  = "v${join(".", regex("(\\d+\\.\\d+\\.\\d+)-(\\d+)", local.vm_name))}"
      i915_sriov_version       = var.i915_sriov_version
      i915_sriov_kernel_series = var.i915_sriov_kernel_series
    }
  }
}

build {
  sources = ["source.proxmox-clone.k3s"]

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/k3s.sh"
    env = {
      I915_SRIOV_VERSION       = var.i915_sriov_version
      I915_SRIOV_KERNEL_SERIES = var.i915_sriov_kernel_series
    }
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
      vm_name                  = local.vm_name.k3s
      git_tag                  = "v${join(".", regex("(\\d+\\.\\d+\\.\\d+)-(\\d+)", local.vm_name.k3s))}"
      i915_sriov_version       = var.i915_sriov_version
      i915_sriov_kernel_series = var.i915_sriov_kernel_series
    }
  }
}

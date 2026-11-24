build {
  source "source.proxmox-clone.clone" {
    name                 = "k3s"
    vm_id                = var.k3s_vm_id
    vm_name              = local.vm_name.k3s
    template_description = "Debian 13 k3s template - ${formatdate("YYYY-MM-DD.hh:mm:ss.ZZZ", timestamp())}"
  }

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
      git_tag                  = local.git_tag.k3s
      role                     = source.name
      i915_sriov_version       = var.i915_sriov_version
      i915_sriov_kernel_series = var.i915_sriov_kernel_series
    }
  }
}

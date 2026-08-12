iso_name = "debian-13.6.0-amd64-netinst.iso"

# Guest (VF) i915-sriov-dkms release. Deliberately on the 2026.03.05.x backport
# line, not the newest release: Debian 13 ships the 6.12 kernel series, which
# the 2026.08.12.x line does not support. The Proxmox host (PF) runs a
# different, newer release on purpose — they do not have to match.
# renovate: datasource=github-releases depName=strongtz/i915-sriov-dkms
i915_sriov_version = "2026.03.05.6"

# Kernel series this image is expected to boot. Single source of truth for the
# guest side: CI validates it against the release above using upstream release
# metadata, and bootstrap.sh re-checks the kernel the image actually has.
i915_sriov_kernel_series = "6.12"

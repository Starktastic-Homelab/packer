iso_name = "debian-13.7.0-amd64-netinst.iso"

# Guest (VF) i915-sriov-dkms release. Deliberately on the 2025.12.10.x
# maintenance line for legacy kernels (6.12–6.18), not the newest release:
# Debian 13 ships the 6.12 kernel series, which the newest line does not
# support. The older 2026.03.05.x backport line stopped building on Debian
# 6.12.113+ (strongtz/i915-sriov-dkms#502). The Proxmox host (PF) runs a
# different, newer release on purpose — they do not have to match.
# renovate: datasource=github-releases depName=strongtz/i915-sriov-dkms
i915_sriov_version = "2025.12.10.2"

# Kernel series this image is expected to boot. Single source of truth for the
# guest side: CI validates it against the release above using upstream release
# metadata, and bootstrap.sh re-checks the kernel the image actually has.
i915_sriov_kernel_series = "6.12"

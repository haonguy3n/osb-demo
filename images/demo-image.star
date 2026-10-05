# One Ubuntu image that boots under stock Secure Boot keys, plus a C++ program
# built from source and an installer ISO for it.
#
#   bootloader: shim       firmware -> shim-signed -> the distro's signed GRUB ->
#                          the distro's signed kernel. Canonical's signatures,
#                          so nothing has to be enrolled in the firmware.
#
#   features:   readonly   read-only root with a tmpfs overlay
#               tpm        TPM support in the initramfs and for osb-tpm
#               encrypt    /data is LUKS2, its key sealed to the TPM on first boot
#               ab         two root slots (root-a, root-b) sharing /data, with
#                          GRUB's boot counting falling back after a failed boot
#
#   packages:   BASE_PACKAGES plus "hello", the C++ unit in units/hello, which
#               installs /usr/bin/hello and enables hello.service.
#
# verity and secureboot are deliberately absent: they need osb's own signed UKI,
# because a root hash only means something in a signed command line, and on the
# shim path grub.cfg and the initramfs are the distro's unsigned ones.
#
# `osb build` writes <image>.img, <image>.img.bmap (what bmaptool follows) and
# the SBOM; `iso = True` adds <image>.iso, a hybrid BIOS/UEFI installer.
load("@core//classes/image.star", "image")
load("@core//classes/baseline.star", "BASE_DISTRO_PACKAGES", "BASE_PACKAGES")

image(
    name = "demo-image",
    packages = BASE_PACKAGES + ["hello"],
    distro_packages = BASE_DISTRO_PACKAGES,
    bootloader = "shim",
    features = ["readonly", "encrypt", "tpm", "ab"],
    iso = True,
)

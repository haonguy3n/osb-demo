# One Ubuntu image with every feature osb has, plus a C++ program built from
# source, and an installer ISO for it.
#
#   features:   secureboot  signed UKI, the only way in under Secure Boot
#               verity      dm-verity root, its hash anchored in the UKI cmdline
#               readonly    read-only root with a tmpfs overlay (implied by verity)
#               tpm         TPM support in the initramfs and for osb-tpm
#               encrypt     /data is LUKS2, its key sealed to the TPM on first boot
#               ab          two root slots (root-a, root-b) sharing /data
#
#   packages:   BASE_PACKAGES plus "hello", the C++ unit in units/hello, which
#               installs /usr/bin/hello and enables hello.service.
#
# `osb build` writes <image>.img, <image>.img.bmap (what bmaptool follows) and
# the SBOM; `iso = True` adds <image>.iso, a hybrid BIOS/UEFI installer.
load("@core//classes/image.star", "image")
load("@core//classes/baseline.star", "BASE_DISTRO_PACKAGES", "BASE_PACKAGES")

image(
    name = "demo-image",
    packages = BASE_PACKAGES + ["hello"],
    distro_packages = BASE_DISTRO_PACKAGES,
    features = ["secureboot", "verity", "readonly", "encrypt", "tpm", "ab"],
    iso = True,
)

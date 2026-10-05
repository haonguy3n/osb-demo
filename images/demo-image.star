# One image, two ways to use it:
#
#   osb build demo-image                     # -> demo-image.img + .img.bmap
#   osb run -iso demo-image                  # -> boot the installer in QEMU
#
# `osb build` always writes <image>.img, <image>.img.bmap and
# <image>.sbom.json; the bmap is what makes `bmaptool` (or `osb flash`) write
# only the blocks that exist. `iso = True` adds <image>.iso, a hybrid BIOS/UEFI
# ISO that boots the image's own kernel and installs it onto a target disk.
#
# The last partition grows to fill whatever media it lands on, so the image can
# be small and the SSD or SD card still ends up fully used after the first boot.
load("@core//classes/image.star", "image")
load("@core//classes/baseline.star", "BASE_DISTRO_PACKAGES", "BASE_PACKAGES", "BASE_SERVICES")

_ALPINE_EXTRA = ["ca-certificates", "curl", "nano"]
_APT_EXTRA = ["ca-certificates", "curl", "nano"]

image(
    name = "demo-image",
    packages = BASE_PACKAGES,
    distro_packages = {
        "alpine": BASE_DISTRO_PACKAGES["alpine"] + _ALPINE_EXTRA,
        "debian": BASE_DISTRO_PACKAGES["debian"] + _APT_EXTRA,
        "ubuntu": BASE_DISTRO_PACKAGES["ubuntu"] + _APT_EXTRA,
    },
    services = BASE_SERVICES,
    iso = True,
)

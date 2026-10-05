# The project's second image, and the other half of the Secure Boot story: osb's
# own signed UKI behind the distro's shim, with dm-verity and a read-only
# overlay.
#
#   firmware -> shim (stock keys already trust it) -> osb's signed UKI
#            (verified against MOK) -> dm-verity root
#
# The UKI is kernel, initramfs and command line signed as one binary, and the
# verity root hash lives in that command line - which is what makes verity here
# mean something, unlike the shim + GRUB chain in images/demo-image.star, where
# grub.cfg and the initramfs are the distro's unsigned ones.
#
# The trade, and the reason this is a second image rather than a flag on the
# first: shim has to be told to trust osb's certificate, once, at the console.
# The certificate ships on the ESP at EFI/osb/osb.crt (DER, plus PEM for
# mokutil). So a freshly flashed disk needs a MokManager confirmation at first
# boot, or `mokutil --import /osb/osb.crt` from a live installer, before it will
# boot. images/demo-image.star boots with nothing enrolled; this one does not.
#
# No installer ISO here on purpose: the ISO's own bootloader is Limine, which is
# unsigned, so installing this image would need Secure Boot off in the first
# place. Add iso = True once the installer enrols osb's key before it writes the
# target, and the ISO becomes the natural way to deploy this image.
load("@core//classes/image.star", "image")
load("@core//classes/baseline.star", "BASE_DISTRO_PACKAGES", "BASE_PACKAGES")

image(
    name = "verity-image",
    packages = BASE_PACKAGES + ["hello"],
    distro_packages = BASE_DISTRO_PACKAGES,
    bootloader = "shim",
    features = ["secureboot", "verity"],
)

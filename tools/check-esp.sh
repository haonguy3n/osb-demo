#!/bin/sh
# Check that the signed boot chain really is on the ESP of an osb image, not just
# installed in its rootfs - reading the files out of the partition, which is what
# the firmware will do. FAT directory entries are not plain text, so this uses
# mtools (the same tooling osb writes the ESP with) rather than grepping the raw
# image:
#
#   tools/check-esp.sh <image.img> grub   shim -> the distro's signed GRUB,
#                                         whose config is osb's
#   tools/check-esp.sh <image.img> uki    shim -> osb's signed UKI (the verity
#                                         root hash is inside it) plus the
#                                         certificate MOK enrols
set -eu

img=${1:?usage: check-esp.sh <image.img> grub|uki}
chain=${2:?usage: check-esp.sh <image.img> grub|uki}
[ -f "$img" ] || { echo "FAIL $img does not exist"; exit 1; }

for tool in sfdisk mdir mcopy; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL $tool is not installed (mtools, util-linux)"
        exit 1
    }
done

# The ESP is the first partition.
parts=$(sfdisk -d "$img" | sed -n 's/.*img1 : start= *\([0-9]*\), size= *\([0-9]*\).*/\1 \2/p')
[ -n "$parts" ] || { echo "FAIL cannot read the partition table of $img"; exit 1; }
fat="$img@@$(( ${parts% *} * 512 ))"

fail() { echo "FAIL $1"; exit 1; }
read_fat() { # read_fat <path on the ESP>
    mcopy -o -i "$fat" "::$1" - 2>/dev/null || fail "cannot read $1 from the ESP"
}

mdir -i "$fat" ::/ >/dev/null 2>&1 || fail "the first partition is not a readable ESP"
read_fat /EFI/BOOT/BOOTX64.EFI | grep -aq 'UEFI SHIM' || fail "shim is not the ESP's boot file"

case "$chain" in
    grub)
        read_fat /EFI/ubuntu/grub.cfg | grep -aq 'osb.overlay=tmpfs' ||
            fail "osb's grub.cfg is not on the ESP (EFI/ubuntu/grub.cfg)"
        echo "ok: shim -> the distro's signed GRUB, with osb's grub.cfg, on the ESP of $img"
        ;;
    uki)
        read_fat /EFI/BOOT/grubx64.efi | grep -aq 'roothash=' ||
            fail "the second stage is not a UKI carrying the verity root hash"
        # Straight through a pipe: the certificate is binary, and a shell
        # variable would silently strip its NUL bytes.
        read_fat /EFI/osb/osb.crt | openssl x509 -inform der -noout -subject 2>/dev/null |
            grep -q 'osb Secure Boot' ||
            fail "EFI/osb/osb.crt on the ESP is not a DER certificate signed by osb"
        echo "ok: shim -> osb's signed UKI (roothash inside) and osb's certificate on the ESP of $img"
        ;;
    *)
        fail "unknown chain $chain (want grub or uki)"
        ;;
esac

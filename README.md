# osb-demo

An [osb](https://github.com/haonguy3n/osb) project: one Ubuntu image that boots
through the distro's own signed boot chain, a C++ application built from source,
and an installer ISO.

| artifact | what it is |
| --- | --- |
| `demo-image.img` | the disk image |
| `demo-image.img.bmap` | block map: `bmaptool` writes only the blocks that exist, and verifies them |
| `demo-image.iso` | hybrid BIOS/UEFI installer ISO that writes the image onto an internal disk |
| `demo-image.sbom.json` | the package list that went into the image |

Features: `readonly` (read-only root with a tmpfs overlay), `tpm` + `encrypt`
(`/data` is LUKS2 with its key sealed to the TPM on first boot) and `ab` (two
root slots sharing `/data`, with GRUB's boot counting falling back to the other
slot after a failed boot). The last partition grows to fill the media on first
boot, so the image can be small and a 32 GB SSD or SD card still ends up used.

**Secure Boot** comes from Canonical, not from osb: `bootloader = "shim"` puts
`shim-signed` (signed by Microsoft's UEFI CA, so stock firmware trusts it) and
the distro's signed GRUB and kernel on the ESP. The image boots under the keys
the machine already has — nothing to enrol, no custom key material.

## Prerequisites

- Docker (osb builds every unit in a container).
- `osb` from its latest release:

  ```sh
  curl -fsSL -o osb https://github.com/haonguy3n/osb/releases/latest/download/osb-linux-amd64
  chmod +x osb && sudo install -m 0755 osb /usr/local/bin/osb
  osb version
  ```

  (Or `cd ~/Projects/osb && go build -o ~/.local/bin/osb ./cmd/osb`.)
- `bmap-tools` to flash.
- Only for a QEMU test: `qemu-system-x86` and `ovmf` (osb picks the OVMF build
  whose variable store carries the vendor keys on this path); add `swtpm` for
  the `tpm`/`encrypt` features and `virt-firmware` when running an osb-signed UKI
  image.

## Build

```sh
make build                      # -> build/ubuntu/demo-image.x86_64/destdir/
make check                      # verify the bmap describes the image exactly
```

Artifacts land in `build/<distro>/demo-image.<machine>/destdir/`.

## Flash it to an SSD or SD card

```sh
make list                       # removable disks, so you pick the right one
make flash DISK=/dev/sdb        # bmaptool copy --bmap ..., then verify
```

The equivalent by hand:

```sh
sudo bmaptool copy --bmap build/ubuntu/demo-image.x86_64/destdir/demo-image.img.bmap \
                          build/ubuntu/demo-image.x86_64/destdir/demo-image.img /dev/sdb
```

`osb flash demo-image /dev/sdb` does the same with a confirmation prompt, and
`tools/check-bmap.py` proves beforehand that the bmap and the image agree (every
checksum matches, every skipped block is zero). On first boot the root grows to
the end of the media and the `/data` key is sealed to the machine's TPM.

## Install from the ISO

```sh
make iso DISK=/dev/sdb          # write the installer ISO to a USB stick
```

Boot the stick, answer the installer's prompts and it writes the image to the
disk you pick; the ISO boots on BIOS and UEFI, and the prompts are on the screen
as well as a serial console. Note the ISO's own bootloader is Limine, which is
not signed, so on a machine with Secure Boot enforced you have to turn it off
for the install (the installed system then boots signed). To try the installer
in QEMU, build and run for a `qemu-*` machine, which talks to the serial console:

```sh
make build MACHINE=qemu-x86_64
make run   MACHINE=qemu-x86_64
```

## The C++ application

`units/hello/` is a small C++17 program with a `CMakeLists.txt`; `units/hello.star`
builds it with cmake, installs it as `/usr/bin/hello` and enables
`hello.service`, which runs it once at boot. In the running image:

```sh
hello                    # hello from Linux ... on x86_64
systemctl status hello   # run once at boot, output in the journal
```

## Things to know before you ship this

- **TPM**: `encrypt`/`tpm` seal the `/data` key to the TPM of the machine that
  boots the image, so it needs one (QEMU uses `swtpm`). Without a TPM the
  initramfs stops with "no TPM found to seal the encryption key".
- **Why there is no verity here**: dm-verity needs its root hash in a *signed*
  command line. On this boot chain `grub.cfg` and the initramfs are the distro's
  unsigned ones, so a root hash there would prove nothing; osb refuses the
  combination. For an integrity-checked root you need osb's own signed UKI
  (`secureboot` + `verity`), which means enrolling the key you sign with.
- **A/B commits are manual**: GRUB falls back to the other slot after a failed
  boot, but nothing yet marks a slot good or points the update at B.
- **Size**: two root slots with an encrypted `/data` make the image a few GB.

## CI

`.github/workflows/build.yml` builds the image and ISO, checks the bmap and that
the signed chain and our `grub.cfg` are actually on the ESP, and uploads
`demo-image.img`, the bmap, the ISO and the SBOM as an artifact kept for 30 days.
It installs osb from its latest release, falling back to a source build when no
release exists yet.

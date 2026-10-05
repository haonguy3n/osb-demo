# osb-demo

An [osb](https://github.com/haonguy3n/osb) project: one Ubuntu image with every
feature osb has, a C++ application built from source, and an installer ISO.

| artifact | what it is |
| --- | --- |
| `demo-image.img` | the disk image |
| `demo-image.img.bmap` | block map: `bmaptool` writes only the blocks that exist, and verifies them |
| `demo-image.iso` | hybrid BIOS/UEFI installer ISO that writes the image onto an internal disk |
| `demo-image.sbom.json` | the package list that went into the image |

Features: `secureboot` (signed UKI), `verity` (dm-verity root, hash anchored in
the signed command line), `readonly` (tmpfs overlay), `tpm` + `encrypt`
(`/data` is LUKS2 with its key sealed to the TPM on first boot), and `ab` (two
root slots sharing `/data`). The last partition grows to fill the media on first
boot, so the image can be small and a 32 GB SSD or SD card still ends up used.

## Prerequisites

- Docker (osb builds every unit in a container).
- `osb` from its latest release:

  ```sh
  curl -fsSL -o osb https://github.com/haonguy3n/osb/releases/latest/download/osb-linux-amd64
  chmod +x osb && sudo install -m 0755 osb /usr/local/bin/osb
  osb version
  ```

  (Or `cd ~/Projects/osb && go build -o ~/.local/bin/osb ./cmd/osb`.)
- Host tooling for the features being built: `systemd-ukify`, `sbsigntool` and
  `mtools` (the signed UKI), `bmap-tools` (flashing).
- Only for a QEMU test: `qemu-system-x86`, `edk2-ovmf`/`ovmf`, `swtpm` and
  `virt-firmware` (the TPM and the Secure Boot variable enrolment).

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
the end of the media.

## Install from the ISO

```sh
make iso DISK=/dev/sdb          # write the installer ISO to a USB stick
```

Boot the stick, answer the installer's prompts and it writes the image to the
disk you pick; the ISO boots on BIOS and UEFI, and the prompts are on the
screen as well as a serial console. To try it in QEMU instead, build and run for
a `qemu-*` machine, which talks to the serial console:

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

Change the source and rebuild: osb caches units by content hash, so only that
unit and the image are rebuilt.

## Things to know before you ship this

- **Secure Boot keys**: without `osb key secure-boot` the image is signed with
  osb's *public test key*. Run that before building and enrol the resulting
  certificate to boot it under enforced Secure Boot. The images CI publishes are
  signed with the test key.
- **TPM**: `encrypt`/`tpm` seal the `/data` key to the TPM of the machine that
  boots the image, so it needs one (QEMU uses `swtpm`). Without a TPM the
  initramfs stops with "no TPM found to seal the encryption key".
- **The ISO is not signed**: the installer's bootloader is Limine, which osb does
  not sign, so installing from the ISO on an enforcing machine means turning
  Secure Boot off (or enrolling Limine) for the install.
- **A/B fallback is not automatic with this loader**: the `ab` feature gives two
  root slots and, with the GRUB loader, GRUB's fallback script. `secureboot`
  forces the UKI loader, which writes a signed UKI per slot but has no
  equivalent fallback yet.
- **Size**: two root slots plus a verity hash partition per slot make the image
  a few GB. Drop `ab` (or `verity`) if you want something smaller.

## CI

`.github/workflows/build.yml` builds the image and ISO, checks the bmap and the
ISO structure, and uploads `demo-image.img`, the bmap, the ISO and the SBOM as
an artifact kept for 30 days. It installs osb from its latest release, falling
back to a source build when no release exists yet.

# osb-demo

An [osb](https://github.com/haonguy3n/osb) project whose one image is both
flashable and installable:

| artifact | what it is |
| --- | --- |
| `demo-image.img` | the disk image |
| `demo-image.img.bmap` | block map: `bmaptool` writes only the blocks that exist and verifies them |
| `demo-image.iso` | hybrid BIOS/UEFI installer ISO that writes the image onto an internal disk |

The last partition grows to fill the media on first boot, so the image stays
small and a 32 GB SSD or SD card still ends up fully used.

## Prerequisites

- Docker (osb builds every unit in a container).
- `osb` built from osb `main` - the console and installer work this project
  relies on lives there:

  ```sh
  cd ~/Projects/osb && go build -o ~/.local/bin/osb ./cmd/osb
  osb version
  ```

- `bmaptool` for flashing (`pacman -S bmap-tools`, `apt install bmap-tools`).
- `qemu-system-x86` + `edk2-ovmf` only if you want to try the ISO without
  touching real hardware.

## Build

```sh
make build                      # alpine, x86_64
make build DISTRO=ubuntu        # the same image from Ubuntu packages
make build MACHINE=arm64        # a UEFI arm64 board or server

# or directly:
osb build demo-image -distro alpine -machine x86_64
```

Artifacts land in `build/<distro>/demo-image.<machine>/destdir/`.

## Flash it to an SSD or SD card

```sh
make list                       # removable disks, so you pick the right one
make flash DISK=/dev/sdb        # bmaptool copy --bmap ..., then verify
```

The equivalent by hand, if you prefer to see it:

```sh
sudo bmaptool copy --bmap build/alpine/demo-image.x86_64/destdir/demo-image.img.bmap \
                          build/alpine/demo-image.x86_64/destdir/demo-image.img /dev/sdb
```

`osb flash demo-image /dev/sdb` does the same thing with a confirmation prompt.
On first boot the root partition is grown to the end of the media.

## Install from the ISO

Write the ISO to a USB stick, boot it on the target machine and answer the
installer's prompts:

```sh
make iso DISK=/dev/sdb
```

Or try it in QEMU first, against a blank disk:

```sh
make run
```

The installer asks which disk to erase and expects `YES`; with
`osb.target=/dev/sda` on the ISO's command line it installs unattended and
powers off. The ISO boots on BIOS and on UEFI, and the installer is visible on
both the screen and a serial console.

## Notes

- **Which kernel**: the `x86_64` and `arm64` machines use the full distro
  kernel (`linux-lts` / `linux-image-generic`), so the installer and the
  installed system can see IDE/SATA, NVMe, USB and the LSI/PVSCSI controllers a
  virtual machine or server uses. The `qemu-*` machines use the stripped-down
  `linux-virt`/`linux-image-virtual` flavours and are meant for CI only.
- **SD cards**: any SD card in a USB reader works, as do the native SD
  controllers in laptops and tablets (`sdhci`). An arm64 `arm64` build needs the
  board to boot generic UEFI images - Raspberry Pi's VideoCore bootloader is not
  something osb produces, so a Pi needs its own UEFI firmware on the SD card
  first.
- **Reproducibility**: every build also writes `demo-image.sbom.json` (a
  CycloneDX package list), and `osb build` caches work per content hash, so
  rebuilds after the first are quick.

## Changing what is in the image

`images/demo-image.star` is the whole definition: add packages to `packages`
(built by osb) or `distro_packages` (taken from the distro's repositories), add
features such as `secureboot`, `verity`, `encrypt`, `tpm`, `ab` or `readonly`,
or define units of your own under `units/`.

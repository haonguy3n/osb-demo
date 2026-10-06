# osb-demo

An [osb](https://github.com/haonguy3n/osb) project with two Ubuntu images that
answer the two halves of Secure Boot, plus an installer ISO and a C++ application
built from source.

| image | boot chain | what it proves |
| --- | --- | --- |
| `demo-image` | firmware → **shim → the distro's signed GRUB and kernel** | boots under stock Secure Boot keys with **nothing enrolled**; `readonly`, `tpm`, `encrypt`, `ab` |
| `verity-image` | firmware → **shim → osb's signed UKI** (verified against MOK) | **dm-verity + readonly** with the root hash in a signed command line, which is why it needs osb's certificate enrolled once |

Each build writes `<image>.img`, `<image>.img.bmap` (what `bmaptool` follows and
verifies) and `<image>.sbom.json`; `demo-image` also has `demo-image.iso`, a
hybrid BIOS/UEFI installer. The last partition grows to fill the media on first
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
- `bmap-tools` to flash, `mtools` for `tools/check-esp.sh`.
- Only for a QEMU test: `qemu-system-x86` and `ovmf` (osb uses the OVMF build
  whose variable store already has the vendor keys), plus `swtpm` for
  `tpm`/`encrypt`.

## Build

```sh
make build                      # demo-image  -> build/ubuntu/demo-image.x86_64/destdir/
make check                      # bmap and ESP: is the signed chain really there?
make build IMAGE=verity-image   # the verity one
make check IMAGE=verity-image
```

`make check` runs `tools/check-bmap.py` (the bmap describes the image exactly,
and every block it skips is zero) and `tools/check-esp.sh`, which reads the ESP
with mtools and checks the chain for that image: shim plus osb's `grub.cfg` for
`demo-image`, or shim plus a UKI carrying the verity root hash and osb's
certificate for `verity-image`.

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

`osb flash demo-image /dev/sdb` does the same with a confirmation prompt. On
first boot the root grows to the end of the media, and for `demo-image` that is
the whole story — it boots under Secure Boot straight away.

### Enrolling osb's key for `verity-image`

`verity-image` boots through osb's own signed UKI, so shim has to be told to
trust osb's certificate before it will run. The certificate is on the ESP at
`EFI/osb/osb.crt` (DER) with the same certificate in PEM as `EFI/osb/osb.pem`,
and nothing is enrolled automatically.

From the console, no password and no tools - the path for a freshly flashed
disk:

1. Boot it. Shim cannot verify the UKI, so it starts **MokManager**.
2. Choose *Enroll key from disk*, pick `EFI/osb/osb.crt`, confirm, and reboot.

From a running system that has the certificate - a live system, or one already
enrolled - for a rotation or a scripted install:

```sh
mokutil --import /EFI/osb/osb.crt     # DER: --import rejects the PEM
mokutil --list-enrolled               # afterwards: osb's key should be listed
mokutil --sb-state                    # and this should say enabled
```

`mokutil --import` asks for a password, which you type in MokManager after the
next reboot; `--revoke-import` cancels a request you no longer want. Either way
it is deliberately a physical-presence step: only someone at the console can add
a key.

## Install from the ISO

```sh
make iso DISK=/dev/sdb          # write demo-image.iso to a USB stick
```

Boot the stick, answer the installer's prompts and it writes the image to the
disk you pick; the ISO boots on BIOS and UEFI and its prompts are on the screen
as well as a serial console. The ISO's own bootloader is Limine, which osb does
not sign, so on a machine with Secure Boot enforced you install with it off; the
installed system then boots signed. To try the installer in QEMU, build and run
for a `qemu-*` machine, which talks to the serial console:

```sh
make build MACHINE=qemu-x86_64
make run   MACHINE=qemu-x86_64
```

There is no ISO for `verity-image` on purpose: that image needs an enrolment
before it boots, so an installer should perform it — the natural next step, and
a one-line `iso = True` once it does.

## Testing in VirtualBox

Both images boot in VirtualBox with UEFI firmware. `demo-image` also needs a
TPM 2.0 for its encrypted `/data`; neither needs a Secure Boot key enrolled,
because VirtualBox does not implement Secure Boot - which is also the one thing
it cannot test about these images. [docs/virtualbox.md](docs/virtualbox.md) has
the setup, what to check inside the guest, the installer's reboot, and a
troubleshooting table; `vbox/create-vm.ps1` does the VBoxManage work:

```powershell
.\vbox\create-vm.ps1 -Mode Image -Source .\verity-image.img -DiskGb 20
.\vbox\create-vm.ps1 -Mode Iso  -Source .\demo-image.iso   -DiskGb 20 -Tpm
```

## The C++ application

`units/hello/` is a small C++17 program with a `CMakeLists.txt`; `units/hello.star`
builds it with cmake, installs it as `/usr/bin/hello` and enables
`hello.service`, which runs it once at boot. Both images include it:

```sh
hello                    # hello from Linux ... on x86_64
systemctl status hello   # run once at boot, output in the journal
```

## Things to know before you ship this

- **Secure Boot keys**: without `osb key secure-boot` the images are signed with
  osb's *public test key* (its subject says DO NOT USE IN PRODUCTION). Run that
  first, rebuild, and enrol the resulting certificate; the enrolled subject is
  then `osb Secure Boot key (<project>)`.
- **TPM**: `encrypt`/`tpm` seal the `/data` key to the TPM of the machine that
  boots the image, so it needs one (QEMU uses `swtpm`). Without a TPM the
  initramfs stops with "no TPM found to seal the encryption key".
- **Why there are two images**: dm-verity needs its root hash in a *signed*
  command line. On `demo-image` the command line comes from the distro's
  unsigned `grub.cfg`, so a root hash there would prove nothing and osb refuses
  the combination; `verity-image` gets a signed one, at the cost of the
  enrolment above. You cannot have both properties in one image.
- **A/B**: `demo-image` has GRUB's boot counting, so it falls back to the other
  slot after a failed boot. `verity-image` cannot: shim loads exactly one signed
  binary, so `ab` is refused with that loader rather than shipping a slot nothing
  can boot. Committing a slot is manual in both cases — nothing yet marks one
  good.
- **Size**: two root slots with an encrypted `/data` make the image a few GB.

## CI

`.github/workflows/build.yml` builds both images, checks the bmap and the chain
on each ESP, and uploads them as artifacts kept for 30 days. It installs osb from
its latest release, falling back to a source build when no release exists yet.

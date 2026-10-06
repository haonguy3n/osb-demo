# Testing an osb image in VirtualBox

VirtualBox is a good place to exercise what these images do: install from the
ISO, grow into the disk, boot the read-only overlay, run the C++ service, and
watch dm-verity come up. It has one limitation that shapes everything below:

> **VirtualBox does not implement Secure Boot.** Nothing verifies firmware keys,
> so `mokutil --sb-state` reports `disabled` and MokManager never appears. That is
> fine for testing *behaviour*, and useless for testing the *security property*.

Both images are UEFI: with BIOS firmware they will not boot. Everything here
therefore starts with **Enable EFI**, and `demo-image` additionally needs a
**TPM 2.0** because it seals the `/data` key to one.

## Which image to start with

| image | VirtualBox needs | why |
| --- | --- | --- |
| `verity-image` | EFI | the simple one: no TPM, and with Secure Boot off shim loads the UKI without asking for a key |
| `demo-image` | EFI + TPM 2.0 | it has `encrypt`+`tpm`: the `/data` key is sealed to a TPM on first boot |
| `demo-image.iso` | EFI (BIOS works too) | the installer; best tried with a fresh, empty disk |

Boot `verity-image` first. It proves the whole boot chain, the overlay and verity
in one shot, with no TPM to configure.

## Scripted

`vbox/create-vm.ps1` creates the VM, converts or creates the disk, and attaches
everything:

```powershell
# boot the raw image directly (what flashing does), grown to 20 GB
.\vbox\create-vm.ps1 -Mode Image -Source .\verity-image.img -DiskGb 20

# or install demo-image from its ISO onto a fresh disk, with a TPM
.\vbox\create-vm.ps1 -Mode Iso -Source .\demo-image.iso -DiskGb 20 -Tpm

VBoxManage startvm osb-ubuntu
```

Add `-VmName`/`-VmDir` to keep several around. It refuses to touch an existing VM
of the same name rather than clobbering it.

## By hand (the GUI does the same thing)

1. **New** → Type *Linux*, Version *Ubuntu (64-bit)* → "Do not add a virtual hard
   disk" (Image mode attaches one; Iso mode creates an empty one).
2. **System → Motherboard** → *Enable EFI*. For `demo-image`, **System → TPM** →
   *2.0*.
3. **Storage** → add a SATA controller → attach the disk and, in Iso mode, the ISO
   as an optical drive.

The ISO and the images come from CI; the end of the main README has the two
commands that fetch them. (Older VirtualBox releases spell the TPM option
`--tpm-type 2` rather than `2.0`.)

For Image mode, convert the raw image first — it is a disk, not a container:

```bat
VBoxManage convertfromraw verity-image.img osb-ubuntu.vdi --format VDI
VBoxManage modifymedium disk osb-ubuntu.vdi --resize 20480
```

Resize **before** the first boot: the image grows its last partition to fill the
media on first boot, which is how a 2 GB image ends up using the whole disk. If
you skip it, the guest is still correct, just small.

## What to check inside the guest

Paste this in; it is the same set of facts the CI assertions look at, minus the
ones VirtualBox cannot provide:

```sh
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS     # esp, root, hash, data
cat /proc/cmdline                               # root=, osb.overlay=, roothash=, osb.slot=
findmnt -no SOURCE,FSTYPE,OPTIONS /             # the overlay
touch /writable-test && echo "writes land in the overlay" && rm /writable-test
veritysetup status root                         # verity-image: active, root hash
dmsetup table root                              # ... and the mapping is verity
hello                                           # the C++ app
systemctl status hello --no-pager               # ran once at boot
df -h /                                         # the first-boot grow
systemctl --failed --no-pager                   # expect none
mokutil --sb-state 2>/dev/null || echo "no mokutil here (demo-image)"
```

What good looks like: `/` is an `overlay` with a read-only lower, `hello` prints a
line it wrote at boot, `df -h /` matches the disk size you gave the VM, and on
`verity-image` the `roothash=` in `/proc/cmdline` is character-for-character the
"Root hash" from `veritysetup status root`. That last equality is the whole point
of the image: the hash the kernel checks is the one its command line carries.

## Installing from the ISO, and the reboot

Boot the VM with the ISO attached and it installs to the empty disk. When it
finishes, **detach the ISO** (Storage → the optical drive → Remove disk from
virtual drive), or from `VBoxManage`:

```bat
VBoxManage storageattach osb-ubuntu --storagectl SATA --port 1 --device 0 --type dvddrive --medium none
```

The installer waits for exactly that and reboots as soon as the medium is gone.
If you leave it attached it says so and waits rather than rebooting into itself —
which is what it used to do.

## Troubleshooting

| symptom | cause |
| --- | --- |
| EFI shell prompt instead of a boot | firmware still on BIOS, or the disk/ISO is not attached (the ESP has `EFI/BOOT/BOOTX64.EFI`; nothing else is bootable) |
| reboots after ~30 s, mentioning `no TPM found to seal the encryption key to` | `demo-image` without TPM 2.0 enabled — add it, or test `verity-image` |
| the installer starts again after install | the ISO is still attached; detach it (see above) |
| `mokutil --sb-state` says `disabled` | expected: VirtualBox has no Secure Boot |
| `/` is not an overlay | you booted a different image, or the cmdline lost `osb.overlay=` |
| the disk looks 2 GB | the VDI was not resized before the first boot; resize and reboot to grow |

## What VirtualBox cannot test

Secure Boot itself, and therefore MOK enrolment. In a VM without Secure Boot,
shim verifies nothing: `verity-image` comes up without the MokManager step, and
dm-verity still runs but is no longer anchored by a signed command line. To test
the enforcement paths, use QEMU with OVMF (osb's CI does exactly that on every
pull request: `signed-shim` and `verity-shim`), or real hardware, where a
freshly flashed `verity-image` stops in MokManager until you enrol
`EFI/osb/osb.crt` from its ESP.

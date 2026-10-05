DISTRO ?= ubuntu
MACHINE ?= x86_64
IMAGE ?= demo-image
DEST := build/$(DISTRO)/$(IMAGE).$(MACHINE)/destdir

.PHONY: build check run flash iso list key clean

## Build the disk image, its bmap and (for demo-image) the installer ISO.
build:
	osb build $(IMAGE) -distro $(DISTRO) -machine $(MACHINE)
	@ls -l $(DEST)/$(IMAGE).img $(DEST)/$(IMAGE).img.bmap

## Prove the bmap describes the image, and the signed chain is on the ESP.
check:
	tools/check-bmap.py $(DEST)/$(IMAGE).img
	tools/check-esp.sh $(DEST)/$(IMAGE).img "$(CHAIN)"

CHAIN = $(if $(filter verity-image,$(IMAGE)),uki,grub)

## Boot the installer ISO in QEMU. Use MACHINE=qemu-x86_64 for a serial console.
run:
	osb run -iso $(IMAGE) -distro $(DISTRO) -machine $(MACHINE)

## Flash the image to a disk, e.g. make flash DISK=/dev/sdb
flash:
	@test -n "$(DISK)" || { echo "usage: make flash DISK=/dev/sdX   (see: make list)"; exit 2; }
	sudo bmaptool copy --bmap $(DEST)/$(IMAGE).img.bmap $(DEST)/$(IMAGE).img $(DISK)

## Write the installer ISO to a USB stick, e.g. make iso DISK=/dev/sdb
iso:
	@test -n "$(DISK)" || { echo "usage: make iso DISK=/dev/sdX   (see: make list)"; exit 2; }
	sudo dd if=$(DEST)/$(IMAGE).iso of=$(DISK) bs=4M status=progress oflag=direct conv=fsync

## Show removable disks so you can pick the right one.
list:
	osb flash list

## Create this project's own Secure Boot key (otherwise osb's test key is used).
key:
	osb key secure-boot

clean:
	osb clean -all

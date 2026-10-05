DISTRO ?= alpine
MACHINE ?= x86_64
IMAGE ?= demo-image
DEST := build/$(DISTRO)/$(IMAGE).$(MACHINE)/destdir

.PHONY: build iso run flash list clean

## Build the disk image, its bmap and the installer ISO.
build:
	osb build $(IMAGE) -distro $(DISTRO) -machine $(MACHINE)
	@ls -l $(DEST)/$(IMAGE).img $(DEST)/$(IMAGE).img.bmap $(DEST)/$(IMAGE).iso

## Boot the installer ISO in QEMU against a blank disk.
run:
	osb run -iso $(IMAGE) -distro $(DISTRO) -machine $(MACHINE)

## Flash the image to a disk, e.g. make flash DISK=/dev/sdb
## bmaptool skips the blocks the bmap marks empty and verifies checksums.
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

clean:
	osb clean -all

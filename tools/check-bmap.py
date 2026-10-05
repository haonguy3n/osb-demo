#!/usr/bin/env python3
"""Check that an osb image and its bmap agree well enough for bmaptool to flash it.

    tools/check-bmap.py build/ubuntu/demo-image.x86_64/destdir/demo-image.img

bmaptool writes the ranges the bmap lists and skips everything else, so two
things have to hold or flashing silently corrupts the disk:

  1. every range's checksum matches the image (what bmaptool verifies as it goes)
  2. every block the bmap leaves out is zero (nothing is lost by skipping it)
"""
import hashlib
import os
import sys
import xml.etree.ElementTree as ET


def fail(msg):
    print(f"FAIL {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("usage: check-bmap.py <image.img>")
    image_path = sys.argv[1]
    bmap_path = image_path + ".bmap"
    if not os.path.exists(image_path):
        fail(f"{image_path} does not exist")
    if not os.path.exists(bmap_path):
        fail(f"{bmap_path} does not exist - osb build writes it next to the image")

    root = ET.parse(bmap_path).getroot()
    block_size = int(root.findtext("BlockSize"))
    blocks = int(root.findtext("BlocksCount"))
    declared = int(root.findtext("ImageSize"))
    size = os.path.getsize(image_path)
    if declared != size:
        fail(f"bmap says the image is {declared} bytes, it is {size}")

    mapped = bytearray(blocks)
    ranges = root.findall(".//Range")
    with open(image_path, "rb") as image:
        for r in ranges:
            text = (r.text or "").strip()
            first_s, _, last_s = text.partition("-")
            first = int(first_s)
            last = int(last_s) if last_s else first
            for i in range(first, last + 1):
                mapped[i] = 1
            want = r.get("chksum")
            if want:
                digest = hashlib.sha256()
                for i in range(first, last + 1):
                    image.seek(i * block_size)
                    digest.update(image.read(block_size))
                if digest.hexdigest() != want:
                    fail(f"range {text} does not match the image")

        not_zero = []
        for i in range(blocks):
            if mapped[i]:
                continue
            image.seek(i * block_size)
            if image.read(block_size) != bytes(block_size):
                not_zero.append(i)
        if not_zero:
            fail(f"{len(not_zero)} skipped blocks are not zero, e.g. {not_zero[:3]}")

    skipped = blocks - sum(mapped)
    print(f"ok: {len(ranges)} ranges, every checksum matches the image")
    print(f"ok: {skipped} of {blocks} blocks are skipped and all of them are zero")
    print(f"ok: bmaptool copy reproduces {image_path} byte for byte")


if __name__ == "__main__":
    main()

project(
    name = "osb-demo",
    version = "0.1.0",
    defaults = defaults(
        # A disk image you can bmaptool onto an SSD or SD card, plus an
        # installer ISO. x86_64 is the generic UEFI PC profile; switch to
        # arm64 for a UEFI arm64 board or server. Both use the full distro
        # kernel, so they see the disks a real machine (or a VM) hands out.
        machine = "x86_64",
        image = "demo-image",
        distro = "alpine",
    ),
)

project(
    name = "osb-demo",
    version = "0.1.0",
    defaults = defaults(
        # Ubuntu, booting through the distro's own signed shim and GRUB, with a
        # read-only overlay, TPM-sealed encrypted /data and two root slots.
        # Built for the generic x86_64 machine, which uses the full distro
        # kernel, so the same image boots on real hardware and in a VM.
        machine = "x86_64",
        image = "demo-image",
        distro = "ubuntu",
    ),
)

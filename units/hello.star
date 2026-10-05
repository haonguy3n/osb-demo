# The C++ application: built from the source next to this file with cmake, then
# installed into the image as /usr/bin/hello and run at boot by hello.service.
#
# `services = ["hello"]` is what enables the unit in the image: for apt images osb
# materialises the systemd symlink, for OpenRC distros it would link into the
# default runlevel.
load("@core//classes/cmake.star", "cmake")

cmake(
    name = "hello",
    version = "1.0.0",
    source = "./hello",
    services = ["hello"],
    distro_runtime_deps = {
        "ubuntu": ["libstdc++6"],
        "debian": ["libstdc++6"],
        "alpine": ["libstdc++"],
    },
    tasks = [
        task("service", steps = [
            install_file("hello.service", "$DESTDIR/usr/lib/systemd/system/hello.service"),
        ]),
    ],
)

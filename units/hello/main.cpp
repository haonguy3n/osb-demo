// A small C++ program, built by osb with cmake and shipped in the image as
// /usr/bin/hello. hello.service runs it once at boot, so it also shows up in
// `systemctl status hello` and in the journal.
#include <cstdio>
#include <cstdlib>
#include <sys/utsname.h>

int main() {
    utsname u{};
    if (uname(&u) != 0) {
        std::perror("uname");
        return 1;
    }
    std::printf("hello from %s %s on %s\n", u.sysname, u.release, u.machine);
    if (const char *user = std::getenv("USER")) {
        std::printf("running as %s\n", user);
    }
    return 0;
}

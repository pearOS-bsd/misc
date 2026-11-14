# open: Mach-O programs that draw straight into wsd

A Mach-O x86_64 program built on a Mac (`sh build.sh`, uses `-DWS_DARWIN_ON_BSD` and the libwsclient sources of `../src`) runs under darwinator on FreeBSD and talks to wsd with the native protocol: connect, create a window, paint its shared memory, order it in.
`WS_DARWIN_ON_BSD` makes `src/ipc.c` use sequenced packets and the FreeBSD layout of control messages (data at +16, 8 byte alignment).

# wsbsd

A window server and compositor for FreeBSD (no X11, no Wayland) that speaks the **message layout of macOS's WindowServer (SkyLight)**, so that
clients written against that contract can be ported. Written in C99; the headless build runs on FreeBSD and macOS.

    gmake            # wsd, test_window and the tests  (make on macOS)
    gmake check      # compositor, region, event-record, buffer and wire-conformance tests
    gmake demo       # starts wsd, draws a test window through the protocol, writes window.ppm (+ window.png)
    gmake kms        # FreeBSD: DRM/KMS display and evdev input (libdrm)          UNTESTED
    gmake gl         # FreeBSD: OpenGL ES 2 compositor on EGL/GBM (Mesa)          UNTESTED on real hardware
    ./wsd -r gl      # use the GL compositor, falling back to software when EGL is unavailable

## Status
Working and tested (CI: FreeBSD x86_64, macOS): the wire protocol for 29 routines with byte-exact layouts, region and event-record formats
(golden vectors from a live system), a software compositor with shadows, shared-memory surfaces, input routing, a connection handshake with an
asynchronous event channel.
Written but not verified on real hardware: DRM/KMS and evdev backends, GBM/dma-buf buffers, the OpenGL ES compositor.
About 700 other SkyLight routines are not implemented and will be added when a client needs them.

See `docs/DESIGN.md` (architecture and status) and `docs/SPEC-SLS-WIRE.md` (the protocol facts, each tagged as decompiled, observed or inferred).

## Provenance
The protocol facts were obtained by analysing a macOS installation the author owns (decompilation with Ghidra through REA, and black-box probing
of public and private APIs on the running system) for the purpose of interoperability. No Apple code is included; the implementation is original.
The raw tables of Apple routine names and addresses are not published. Anyone redistributing or building on this should check the licence terms
that apply to them.


## Install and run

```
gmake                      # or: gmake kms / gmake gl / gmake full on FreeBSD with libdrm / Mesa
gmake check                # the whole test suite, including an install smoke test
doas gmake install         # PREFIX=/usr/local: wsd, wsshot/wsclick/wskey/wsdrag, wsstart, libwsclient.a + headers, rc.d script, wsd(8)
wsstart -- your-client     # a private server for this user, stopped when the client exits
```

As a service: `sysrc wsd_enable=YES wsd_user=alice wsd_flags="-b kms -r gl -S"` then `service wsd start`; clients find the socket through
`XDG_RUNTIME_DIR` (`/var/run/wsd/wsd.sock` with the rc script's defaults) or `WS_SOCKET`. See `man wsd` and `docs/FREEBSD.md`.

#!/bin/sh
# Installs into a scratch directory, starts a private server through wsstart and takes a screenshot with the installed tools: the packaged product works end to end.
set -e
cd "$(dirname "$0")/.."
D="${TMPDIR:-/tmp}/wsbsd-inst.$$"
trap 'rm -rf "$D"' EXIT
make install DESTDIR="$D" PREFIX=/usr/local >/dev/null
P="$D/usr/local"
for f in sbin/wsd bin/wsshot bin/wsstart etc/rc.d/wsd share/man/man8/wsd.8 lib/libwsclient.a include/wsbsd/ws_client.h; do [ -e "$P/$f" ] || { echo "missing $f"; exit 1; }; done
sh -n "$P/etc/rc.d/wsd" && sh -n "$P/bin/wsstart"
if command -v mandoc >/dev/null 2>&1; then mandoc -Tlint -Wwarning "$P/share/man/man8/wsd.8" || true; fi
PREFIX="$P" WSD_FLAGS="-t -g 320x200" "$P/bin/wsstart" -- "$P/bin/wsshot" "$D/shot.ppm"
head -c 2 "$D/shot.ppm" | grep -q P6 || { echo "no screenshot"; exit 1; }
echo "install: ok"

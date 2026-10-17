#!/bin/sh
# Extended attributes and the Gatekeeper verdict, on a file system that has them (FreeBSD UFS2 / ZFS; not tmpfs, not cd9660):  sh iso/test/xattr-test.sh [dir]
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"; WS="$HERE/.."
D="${1:-/var/tmp/xattr-test.$$}"; mkdir -p "$D"; trap 'rm -rf "$D"' EXIT
cc -O1 -Wall -I"$WS/sdk/include" -o "$D/xattr" "$HERE/src/xattr.c" "$WS/sdk/src/xattr.c"
cc -O1 -Wall -I"$WS/sdk/include" -o "$D/spctl" "$HERE/src/spctl.c" "$WS/sdk/src/xattr.c"
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; exit 1; }
f="$D/file"; echo hello > "$f"
"$D/xattr" -w com.apple.FinderInfo "x" "$f";                                   ok "write"
[ "$("$D/xattr" -p com.apple.FinderInfo "$f")" = x ] || bad "read back";       ok "read back"
"$D/xattr" "$f" | grep -qx com.apple.FinderInfo || bad "list";                  ok "list"
# the quarantine attribute and the verdict
q="0083;$(printf %08x "$(date +%s)");Safari;7B1C5F10-0000-4000-8000-000000000001"
"$D/xattr" -w com.apple.quarantine "$q" "$f";                                  ok "quarantine written"
"$D/spctl" --assess "$f" >/dev/null 2>&1 && bad "quarantined file accepted"; [ $? -ne 0 ];  ok "quarantined, not approved: rejected"
"$D/xattr" -w com.apple.quarantine "00c3;$(printf %08x "$(date +%s)");Safari;7B1C5F10-0000-4000-8000-000000000001" "$f"
"$D/spctl" --assess "$f" || bad "approved file rejected";                       ok "approved: accepted"
"$D/xattr" -d com.apple.quarantine "$f"; "$D/xattr" "$f" | grep -q quarantine && bad "delete";  ok "delete"
"$D/xattr" -c "$f"; [ -z "$("$D/xattr" "$f")" ] || bad "clear";                 ok "clear"
echo ALL-OK

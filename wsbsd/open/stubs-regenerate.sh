#!/bin/sh
# stubs-regenerate.sh APP ...: the symbols the given Apple applications (names under /System/Applications of the Mac VM) bind from AppKit / Cocoa and from the libraries that must not pull the real AppKit in
# are defined by stand-ins: open/stubs-extra.m (into AppKit) and open/stubs-lib-NAME.m (dylibs /open/stub-NAME).  Run from the root of wsbsd; builds on the Mac VM (ssh 2229), then copies the results back.
#   sh open/stubs-regenerate.sh TextEdit Calculator Stickies "Font Book"
R="$(cd "$(dirname "$0")/.." && pwd)"; T="${CLAUDE_JOB_DIR:-/tmp}/tmp"; mkdir -p "$T"
MK="-i $HOME/fbsd-vm/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o BatchMode=yes"
rm -f "$R"/open/stubs-extra.m "$R"/open/stubs-lib-*.m
sh "$R/open/deploy.sh" hello >/dev/null 2>&1				# AppKit without any stand-in: the symbols it lacks are the ones to define
scp -P 2229 $MK "$R/open/gen-stubs.py" alex@localhost:/tmp/ >/dev/null 2>&1
BINS=""; for a in "$@"; do BINS="$BINS \"/System/Applications/$a.app/Contents/MacOS/$(ssh -p 2229 $MK alex@localhost "defaults read '/System/Applications/$a.app/Contents/Info' CFBundleExecutable" 2>/dev/null)\""; done
ssh -p 2229 $MK alex@localhost "cd /tmp && rm -rf gs && mkdir gs && python3 gen-stubs.py /tmp/gs/stubs-extra.m wsb/out/AppKit $BINS" 2>&1 | grep -v Warn
scp -P 2229 $MK "alex@localhost:/tmp/gs/*.m" "$R/open/" >/dev/null 2>&1
ls "$R"/open/stubs-*.m
sh "$R/open/deploy.sh" hello 2>&1 | grep -i "error\|FAILED" | head -5

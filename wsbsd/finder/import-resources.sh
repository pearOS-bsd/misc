#!/bin/sh
# Brings the resources of the Finder of the reference Mac into the app bundle built by build.sh (they are the Mac's own data and are never committed):
#   sh finder/import-resources.sh /System/Library/CoreServices/Finder.app OUT/System/Library/CoreServices/Finder.app
# Compiled nibs (NIBArchive) are converted to the keyed archives GNUstep reads (tools/nib2plist.py); everything else is copied as it is.
SRC="${1:?Finder.app of the Mac}"; DST="${2:?Finder.app to fill}"; T="$(cd "$(dirname "$0")/.." && pwd)/tools"
R="$SRC/Contents/Resources"; O="$DST/Contents/Resources"; mkdir -p "$O"
(cd "$R" && find . -type f ! -name '*.nib' -o -type d -name '*.lproj' -prune) >/dev/null 2>&1
(cd "$R" && find . -type f | while read f; do
	case "$f" in
	*.nib) d="$O/$f"; mkdir -p "$d"; python3 "$T/nib2plist.py" "$R/$f" "$d" >/dev/null 2>&1 || echo "nib not converted: $f" ;;
	*) mkdir -p "$O/$(dirname "$f")"; cp "$R/$f" "$O/$f" ;;
	esac
done)
ls "$O" | wc -l | awk '{print "resources:", $1, "entries"}'

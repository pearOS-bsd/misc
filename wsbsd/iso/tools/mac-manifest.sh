#!/bin/sh
# Writes the manifest of the reference Mac: PATHS, TYPES AND MODES ONLY (no file contents, nothing of Apple's is copied). Run on the Mac:  sh iso/tools/mac-manifest.sh
# Each line:  <type> <octal mode> <path> [-> link target]   type: d directory, f file, l symlink
OUT="$(cd "$(dirname "$0")/.." && pwd)/manifest"; mkdir -p "$OUT"
sw_vers | sed 's/^/# /' > "$OUT/VERSION.txt"; uname -mrs | sed 's/^/# /' >> "$OUT/VERSION.txt"
emit() {   # emit <root> <maxdepth> : the tree below root, to that depth
	find "$1" -xdev -maxdepth "$2" 2>/dev/null | while IFS= read -r p; do
		if [ -L "$p" ]; then printf 'l %s %s -> %s\n' "$(stat -f %Lp "$p")" "$p" "$(readlink "$p")"
		elif [ -d "$p" ]; then printf 'd %s %s\n' "$(stat -f %Lp "$p")" "$p"
		else printf 'f %s %s\n' "$(stat -f %Lp "$p")" "$p"; fi
	done | sort -k3
}
# what the owner installed (user names, third-party applications, Homebrew) is not part of the reference: only the top level directories of /Users /Volumes /opt /Applications /Library appear
{ for d in / /System /System/Library /usr /usr/lib /usr/bin /usr/sbin /usr/libexec /usr/share /private /private/etc /private/var /bin /sbin /cores; do emit "$d" 1; done; for d in /Users /Volumes /opt /Applications /Library; do emit "$d" 0; done; } | sort -u -k3 > "$OUT/layout.txt"
emit /System 3 | grep -v '^[dfl] [0-7]* /System/Volumes' > "$OUT/system.txt"
emit /System/Library/Frameworks 6 > "$OUT/frameworks.txt"
emit /System/Library/PrivateFrameworks 3 > "$OUT/privateframeworks.txt"
emit /System/Library/CoreServices 3 > "$OUT/coreservices.txt"
emit /System/Applications 3 > "$OUT/system-applications.txt"
emit /usr/lib 2 > "$OUT/usr-lib.txt"
wc -l "$OUT"/*.txt

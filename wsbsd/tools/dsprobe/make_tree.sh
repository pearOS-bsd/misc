#!/bin/sh
# A fixed test tree for the Finder model probes: sh make_tree.sh DIR   (same bytes and dates on every machine)
D="${1:?dir}"; rm -rf "$D"; mkdir -p "$D"; cd "$D" || exit 1
mkdir -p Docs/Sub Empty "Folder With Spaces" App.app/Contents/MacOS Bundle.bundle/Contents Lib.framework/Versions/A
printf 'hello\n' > Docs/readme.txt; printf '# title\n' > Docs/notes.md; printf 'x' > Docs/Sub/a.dat; : > Docs/Sub/empty.bin
printf '\211PNG\r\n\032\n' > Docs/pic.png; printf '<?xml version="1.0"?><plist version="1.0"><dict/></plist>\n' > Docs/data.plist
printf 'secret' > .hidden; printf 'hidden in docs' > Docs/.dotfile; printf 'app' > App.app/Contents/MacOS/App
printf '<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>test.app</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>\n' > App.app/Contents/Info.plist
printf 'tar' > archive.tar; printf 'zip' > archive.zip; printf 'no ext' > noext; printf '%s' 'long' > "name with ünïcode.txt"
ln -s Docs/readme.txt link-to-file; ln -s Docs link-to-dir; ln -s /nonexistent broken-link
chmod 444 Docs/readme.txt; chmod 700 Empty
find . -exec touch -h -t 202501021200 {} +

#!/bin/sh
# Regenerates finder/src/Finder_Generated.mm (the stubs of every class of the Finder that has no hand-written finder/src/Class.mm) from docs/desktop/Finder.dyld_info-objc.txt
cd "$(dirname "$0")/.." || exit 1
python3 tools/gen_from_dyldinfo.py docs/desktop/Finder.dyld_info-objc.txt finder/src/Finder_Generated.mm --system-classes docs/desktop/system-classes.txt --hand-dir finder/src

#!/bin/sh
# Regenerates finder/src/Finder_Generated.mm (the stubs of every class of the Finder that has no hand-written finder/src/Class.mm) from docs/desktop/Finder.dyld_info-objc.txt
cd "$(dirname "$0")/.." || exit 1
python3 tools/impl_skips.py finder/src/*_impl.mm > /tmp/finder.skips 2>/dev/null; touch /tmp/finder.skips
python3 tools/gen_from_dyldinfo.py docs/desktop/Finder.dyld_info-objc.txt finder/src/Finder_Generated.mm --system-classes docs/desktop/system-classes.txt --system-selectors docs/desktop/system-selectors.txt --hand-dir finder/src --skip /tmp/finder.skips

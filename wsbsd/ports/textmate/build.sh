#!/bin/sh
# TextMate (github.com/textmate/textmate) in the FreeBSD VM: sh ports/textmate/build.sh   (state: the frameworks compile up to the blockers listed in README.md; nothing links yet)
set -e
cd /root/oss
[ -d tm ] || git clone --depth 1 https://github.com/textmate/textmate tm
cd tm
git submodule update --init --depth 1
pkg install -y boost-libs boost-all capnproto ragel ninja multimarkdown sparsehash oniguruma ruby bash sqlite3 curl >/dev/null
install -m 755 /root/wsbsd/ports/textmate/xcrun /usr/local/bin/xcrun               # xcrun --sdk macosx clang ... -> clang with the wsbsd SDK flags
printf 'add FLAGS    "-I/usr/local/include"\nadd LN_FLAGS "-L/usr/local/lib"\n' > local.rave
for f in bin/*; do [ -f "$f" ] && sed -i '' '1s#^\#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby#\#!/usr/bin/env ruby#' "$f"; done
sed -i '' 's#cp -Xp#cp -p#' bin/rave                                                 # BSD cp has no -X
ruby bin/rave -crelease -tTextMate
sed -i '' 's#${env}bin/rave#${env}ruby bin/rave#' build.ninja
ninja -k 0 -j4 "$@"

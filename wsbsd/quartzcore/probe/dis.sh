#!/bin/sh
# dis.sh 'regex-or-name' ... : disassemble functions of the real QuartzCore through lldb (symbols come from the loaded shared cache)
cd "$(dirname "$0")"
args=""
for f in "$@"; do args="$args -o \"disassemble -n '$f'\""; done
eval lldb -b -o "'target create /private/tmp/claude-501/-Users-alxb421-Desktop-app/99e54da3-d84c-4f4f-abcf-77e1f01a4997/scratchpad/dbg/p1'" -o "'b main'" -o "'run'" $args 2>&1 | sed -n '/^(lldb) disassemble/,$p'

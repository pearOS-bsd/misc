#!/bin/sh
# dis.sh 'regex-or-name' ... : disassemble functions of the real QuartzCore through lldb (symbols come from the loaded shared cache)
cd "$(dirname "$0")"
args=""
for f in "$@"; do args="$args -o \"disassemble -n '$f'\""; done
eval lldb -b -o "'target create p1'" -o "'b main'" -o "'run'" $args 2>&1 | sed -n '/^(lldb) disassemble/,$p'

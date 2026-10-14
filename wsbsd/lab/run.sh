#!/bin/sh
# Compiles and runs one lab probe (lab/<name>.c) against the real WindowServer of the macOS runner; on a crash prints a backtrace from lldb.
#   usage: sh lab/run.sh <name>      output goes to stdout and to lab-out/<name>.txt
cd "$(dirname "$0")"
mkdir -p ../lab-out
N="$1"
cc -g -O0 -o "../lab-out/$N" "$N.c" -framework CoreGraphics -framework CoreFoundation -framework ApplicationServices 2>&1 | tee "../lab-out/$N.build.txt"
"../lab-out/$N" 2>&1 | tee "../lab-out/$N.txt"
rc=$?
if [ "$rc" -ge 128 ] || grep -q "Segmentation\|Bus error" "../lab-out/$N.txt"; then
  echo "--- crashed, lldb backtrace ---"
  sudo lldb -b -o run -o "bt 12" -o "register read" "../lab-out/$N" 2>&1 | tail -60 | tee -a "../lab-out/$N.txt"
fi

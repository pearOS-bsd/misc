#!/bin/sh
# Compiles and runs one lab probe (lab/<name>.c) against the real WindowServer of the macOS runner; on a crash prints a backtrace from lldb.
#   usage: sh lab/run.sh <name>      output goes to stdout and to lab-out/<name>.txt
cd "$(dirname "$0")"
mkdir -p ../lab-out
N="$1"
if [ -f "$N.sh" ]; then sh "$N.sh"; exit 0; fi
if [ -f "$N.scen" ]; then sh run_scen.sh "$N.scen"; exit 0; fi
cc -g -O0 -o "../lab-out/$N" "$N.c" -framework CoreGraphics -framework CoreFoundation -framework ApplicationServices > "../lab-out/$N.build.txt" 2>&1; cat "../lab-out/$N.build.txt"
"../lab-out/$N" > "../lab-out/$N.txt" 2>&1; rc=$?
cat "../lab-out/$N.txt"
echo "exit code $rc"
if [ "$rc" -ge 128 ]; then
  echo "--- crashed, lldb backtrace ---"
  sudo lldb -b -o run -o "bt 12" -o "register read" "../lab-out/$N" 2>&1 | tail -70 | tee -a "../lab-out/$N.txt"
fi
exit 0

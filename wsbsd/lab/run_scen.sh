#!/bin/sh
# usage (through run.sh): the probe name is the script: lab/<name>.scen is run with the scenario runner
cd "$(dirname "$0")"
mkdir -p ../lab-out
cc -o ../lab-out/portfn portfn.c && cc -g -o ../lab-out/scen scen.c || exit 1
export PORT_FN="$(../lab-out/portfn)"
for s in "$@"; do echo "=== $s"; ../lab-out/scen "$s" 2>&1 | tee "../lab-out/$(basename "$s").out" | cut -c1-300; done

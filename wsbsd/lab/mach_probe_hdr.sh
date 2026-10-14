#!/bin/sh
# golden replies for every header-only routine
cd "$(dirname "$0")"
mkdir -p ../lab-out
cc -g -o ../lab-out/mach_probe mach_probe.c 2>&1 | head
../lab-out/mach_probe ids_hdr.txt > ../lab-out/golden_hdr.txt 2>&1
cat ../lab-out/golden_hdr.txt | cut -c1-240

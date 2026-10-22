#!/bin/sh
# Decompiles Finder functions by address from the local Ghidra project (see docs/desktop/WORKFLOW.md): sh tools/finder_func.sh 0x100015dd4,0x1001fdfe0   (a few seconds each call)
OUT_FILE=/tmp/finder_func.out ADDRS="$1" /opt/homebrew/Cellar/ghidra/12.1.4/libexec/support/analyzeHeadless "$HOME/finder-decomp/proj1" finder -process Finder.bin -noanalysis -readOnly -scriptPath "$HOME/finder-decomp/scripts" -postScript FuncDump.java > /tmp/finder_func.log 2>&1; cat /tmp/finder_func.out

#!/bin/sh
# run.sh LIST OUT : decompile with Ghidra (no auto-analysis) the functions in LIST (lines "0x18xxxxxxx name") of the QuartzCore binary copy
cd "$(dirname "$0")"
S=/private/tmp/claude-501/-Users-alxb421-Desktop-app/99e54da3-d84c-4f4f-abcf-77e1f01a4997/scratchpad
P=/tmp/ghproj; mkdir -p $P
BIN=$S/qcbin/QuartzCore
if [ ! -d $P/qc.rep ]; then
  /opt/homebrew/Cellar/ghidra/12.1.4/libexec/support/analyzeHeadless $P qc -import $BIN -noanalysis -overwrite >$P/import.log 2>&1
fi
/opt/homebrew/Cellar/ghidra/12.1.4/libexec/support/analyzeHeadless $P qc -process QuartzCore -noanalysis -scriptPath "$PWD" -postScript Dec.java "$1" "$2" >$P/dec.log 2>&1
tail -3 $P/dec.log

#!/bin/sh
# trace.sh PROGRAM PATTERN: runs PROGRAM under lldb printing the name of every function matching the regex PATTERN (e.g. '^-\[CWFInterface ') as it is entered; MARK lines of the program separate the calls.
perl -e 'alarm 600; exec @ARGV' lldb -b -o "breakpoint set -r \"$2\"" -o 'breakpoint command add -s python 1 -o "print(frame.GetFunctionName()); return False"' -o 'run' "$1" 2>&1 | grep -v '^(lldb)'

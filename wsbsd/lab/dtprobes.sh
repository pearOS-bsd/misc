#!/bin/sh
sudo dtrace -l 2>&1 | grep -iE "mach|msg" | head -40
sudo dtrace -l 2>&1 | awk '{print $2}' | sort | uniq -c | sort -rn | head

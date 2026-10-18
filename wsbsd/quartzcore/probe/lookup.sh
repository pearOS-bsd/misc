#!/bin/sh
# lookup.sh 'fixed substring' ... : lines "0xSTATIC name" for matching functions
cd "$(dirname "$0")"; for p in "$@"; do grep -F -- "$p" static.txt; done

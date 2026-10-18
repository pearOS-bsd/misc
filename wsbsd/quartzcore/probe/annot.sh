#!/bin/sh
# annot.sh file.s : adds the selector names behind objc_msgSend stubs (bl 0x1a64..) as comments
cd "$(dirname "$0")"; f="$1"
grep -oE '0x1a6[0-9a-f]{6}' "$f" | sed 's/0x//' | sort -u > /tmp/stubs.txt
lldb -b -o "target create /private/tmp/claude-501/-Users-alxb421-Desktop-app/99e54da3-d84c-4f4f-abcf-77e1f01a4997/scratchpad/dbg/p1" -o "b main" -o "run" -o "command script import resolve.py" -o "resolve /tmp/stubs.txt /tmp/stubs.out" >/dev/null 2>&1
python3 -I - "$f" <<'P'
import sys,re
names={l.split()[0]:l.split(None,1)[1].strip() for l in open('/tmp/stubs.out')}
for l in open(sys.argv[1]):
    l=l.rstrip('\n')
    m=re.search(r'\bbl?\s+0x(1a6[0-9a-f]{6})\s*$',l) or re.search(r'\bbl\s+0x(1a6[0-9a-f]{6})\b',l)
    if m and m.group(1) in names: l=l+'   ; -> '+names[m.group(1)]
    print(l[:200])
P

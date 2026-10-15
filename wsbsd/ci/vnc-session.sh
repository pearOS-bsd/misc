#!/bin/sh
# An interactive session for a person: builds the stack, starts wsd with a VNC viewer port and the Terminal, and opens a public TCP tunnel for a limited time.
# usage: sh ci/vnc-session.sh <minutes>
MINUTES="${1:-5}"
. "$(dirname "$0")/gnustep-setup.sh"
cd "$WS"
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsshot tools/wsshot.c /tmp/wsc/libwsclient.a -lm
gmake wsd 2>&1 | tail -2
PW=$(head -c 64 /dev/urandom | tr -dc 'a-zA-Z' | head -c 8)
export WS_SOCKET=/tmp/wsd-vnc.sock
WSD_VNC_PASSWORD="$PW" ./wsd -g 1280x800 -V 5900 >/tmp/wsd.log 2>&1 &
WP=$!
sleep 1
TD="$WS/../terminal"
(cd "$TD" && cc -o Terminal-gnustep src/vt.c src/pty.c src/TermView.m src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) -lutil 2>&1 | grep -E "error" | head)
TERMINAL_COLS=110 TERMINAL_ROWS=30 TERMINAL_INITIAL_INPUT="neofetch
" "$TD/Terminal-gnustep" >/tmp/terminal.log 2>&1 &
sleep 3
# the tunnel: a public host:port forwarded to the viewer port of this machine
rm -f /tmp/tunnel.log
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -o ExitOnForwardFailure=yes -R 5900:127.0.0.1:5900 serveo.net >/tmp/tunnel.log 2>&1 &
TP=$!
i=0; while ! grep -q 'Forwarding' /tmp/tunnel.log 2>/dev/null && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
echo
echo "=========================================================="
echo " VNC session, open for $MINUTES minutes"
if grep -q 'Forwarding' /tmp/tunnel.log; then
	echo " address:  $(grep -o 'serveo.net:[0-9]*' /tmp/tunnel.log | head -1)"
else
	echo " the tunnel did not come up: $(cat /tmp/tunnel.log | tr '\n' ' ')"
fi
echo " password: $PW"
echo " (use any VNC viewer; in the terminal try: neofetch, ls, Sudoku &, Gorm &)"
echo "=========================================================="
echo
sleep $((MINUTES * 60))
kill $TP $WP 2>/dev/null
pkill -f Terminal-gnustep 2>/dev/null
echo "session over"

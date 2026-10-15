#!/bin/sh
# An interactive session for a person: builds the stack, starts wsd with a VNC viewer port and the Terminal, and opens a public TCP tunnel for a limited time.
# usage: sh ci/vnc-session.sh <minutes>
MINUTES="${1:-5}"
. "$(dirname "$0")/gnustep-setup.sh"
cd "$WS"
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsshot tools/wsshot.c /tmp/wsc/libwsclient.a -lm
gmake wsd 2>&1 | tail -2
PW=$(head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z' | head -c 8)
export WS_SOCKET=/tmp/wsd-vnc.sock
WSD_VNC_PASSWORD="$PW" ./wsd -g 1280x800 -V 5900 >/tmp/wsd.log 2>&1 &
WP=$!
sleep 1
TD="$WS/../terminal"
(cd "$TD" && cc -o Terminal-gnustep src/vt.c src/pty.c src/TermView.m src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) -lutil 2>&1 | grep -E "error" | head)
TERMINAL_COLS=110 TERMINAL_ROWS=30 TERMINAL_INITIAL_INPUT="neofetch
" "$TD/Terminal-gnustep" >/tmp/terminal.log 2>&1 &
sleep 3
# the tunnel: a public host:port forwarded to the viewer port of this machine, through an ssh remote forward that needs no account: pinggy.io (tcp), then serveo.net
rm -f /tmp/tunnel.log /tmp/tunnel2.log; ADDR=""
ssh -tt -p 443 -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -o ExitOnForwardFailure=yes -R0:127.0.0.1:5900 tcp@a.pinggy.io >/tmp/tunnel.log 2>&1 </dev/null &
TP=$!
i=0; while ! grep -q 'tcp://' /tmp/tunnel.log 2>/dev/null && [ $i -lt 25 ]; do sleep 1; i=$((i + 1)); done
ADDR="$(grep -o 'tcp://[a-zA-Z0-9.-]*:[0-9]*' /tmp/tunnel.log | head -1 | sed 's|tcp://||')"
if [ -z "$ADDR" ]; then
	kill $TP 2>/dev/null; echo "pinggy: $(tr '\n\r' '  ' < /tmp/tunnel.log | cut -c1-240)"
	ssh -tt -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -o ExitOnForwardFailure=yes -R 5900:127.0.0.1:5900 serveo.net >/tmp/tunnel2.log 2>&1 </dev/null &
	TP=$!
	i=0; while ! grep -q 'Forwarding' /tmp/tunnel2.log 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i + 1)); done
	ADDR="$(grep -o 'serveo.net:[0-9]*' /tmp/tunnel2.log | head -1)"
	[ -n "$ADDR" ] || echo "serveo: $(tr '\n\r' '  ' < /tmp/tunnel2.log | cut -c1-200)"
fi
echo
echo "=========================================================="
echo " VNC session, open for $MINUTES minutes"
if [ -n "$ADDR" ]; then echo " address:  $ADDR"; else echo " no tunnel came up (pinggy.io and serveo.net refused the forward)"; fi
echo " password: $PW"
echo " (use any VNC viewer; in the terminal try: neofetch, ls, Sudoku &, Gorm &)"
echo "=========================================================="
echo
sleep $((MINUTES * 60))
kill $TP $WP 2>/dev/null
pkill -f Terminal-gnustep 2>/dev/null
echo "session over"

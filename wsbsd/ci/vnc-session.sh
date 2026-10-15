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
# the tunnel: a public host:port forwarded to the viewer port of this machine. First choice serveo.net (an ssh remote forward, needs a terminal for its banner), then bore.pub (pkg).
rm -f /tmp/tunnel.log; ADDR=""
ssh -tt -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -o ExitOnForwardFailure=yes -R 5900:127.0.0.1:5900 serveo.net >/tmp/tunnel.log 2>&1 </dev/null &
TP=$!
i=0; while ! grep -q 'Forwarding' /tmp/tunnel.log 2>/dev/null && [ $i -lt 25 ]; do sleep 1; i=$((i + 1)); done
if grep -q 'Forwarding' /tmp/tunnel.log; then ADDR="$(grep -o 'serveo.net:[0-9]*' /tmp/tunnel.log | head -1)"; else
	kill $TP 2>/dev/null; echo "serveo: $(tr '\n\r' '  ' < /tmp/tunnel.log | cut -c1-200)"
	if pkg install -y bore >/dev/null 2>&1 || pkg install -y bore-cli >/dev/null 2>&1; then
		bore local 5900 --to bore.pub >/tmp/tunnel2.log 2>&1 &
		TP=$!
		i=0; while ! grep -q 'bore.pub:' /tmp/tunnel2.log 2>/dev/null && [ $i -lt 20 ]; do sleep 1; i=$((i + 1)); done
		ADDR="$(grep -o 'bore.pub:[0-9]*' /tmp/tunnel2.log | head -1)"
	else echo "bore is not available as a package"; fi
fi
echo
echo "=========================================================="
echo " VNC session, open for $MINUTES minutes"
if [ -n "$ADDR" ]; then echo " address:  $ADDR"; else echo " no tunnel came up (serveo.net and bore.pub unreachable from here)"; fi
echo " password: $PW"
echo " (use any VNC viewer; in the terminal try: neofetch, ls, Sudoku &, Gorm &)"
echo "=========================================================="
echo
sleep $((MINUTES * 60))
kill $TP $WP 2>/dev/null
pkill -f Terminal-gnustep 2>/dev/null
echo "session over"

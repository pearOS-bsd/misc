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
# a browser viewer: noVNC + websockify (WebSocket to VNC), reached through an HTTPS tunnel; plus the raw VNC port through a TCP tunnel for a desktop viewer
cd /tmp && git clone --depth 1 https://github.com/novnc/noVNC.git novnc 2>&1 | tail -1; git clone --depth 1 https://github.com/novnc/websockify.git websockify 2>&1 | tail -1
cd /tmp/websockify && (python3 -m websockify --web /tmp/novnc 6080 127.0.0.1:5900 >/tmp/websockify.log 2>&1 &)
sleep 2
cd "$WS"
rm -f /tmp/tunnel-http.log /tmp/tunnel-tcp.log; URL=""; ADDR=""
ssh -tt -p 443 -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -R0:127.0.0.1:6080 a.pinggy.io >/tmp/tunnel-http.log 2>&1 </dev/null &
TP1=$!
ssh -tt -p 443 -o BatchMode=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=20 -R0:127.0.0.1:5900 tcp@a.pinggy.io >/tmp/tunnel-tcp.log 2>&1 </dev/null &
TP=$!
i=0; while [ $i -lt 30 ]; do grep -q 'https://' /tmp/tunnel-http.log 2>/dev/null && break; sleep 1; i=$((i + 1)); done
URL="$(grep -o 'https://[a-zA-Z0-9.-]*pinggy[a-zA-Z0-9.-]*' /tmp/tunnel-http.log | head -1)"
ADDR="$(grep -o 'tcp://[a-zA-Z0-9.-]*:[0-9]*' /tmp/tunnel-tcp.log | head -1 | sed 's|tcp://||')"
[ -n "$URL" ] || echo "http tunnel: $(tr '\n\r' '  ' < /tmp/tunnel-http.log | cut -c1-240)"
echo
echo "=========================================================="
echo " VNC session, open for $MINUTES minutes"
if [ -n "$URL" ]; then echo " BROWSER:  $URL/vnc.html?autoconnect=true&resize=scale&password=$PW"; else echo " no browser tunnel came up"; fi
if [ -n "$ADDR" ]; then echo " VNC viewer address: $ADDR"; fi
echo " password: $PW"
echo " (use any VNC viewer; in the terminal try: neofetch, ls, Sudoku &, Gorm &)"
echo "=========================================================="
echo
sleep $((MINUTES * 60))
kill $TP $TP1 $WP 2>/dev/null
pkill -f Terminal-gnustep 2>/dev/null
echo "session over"

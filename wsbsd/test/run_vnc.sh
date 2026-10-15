#!/bin/sh
# The VNC server: handshake, (optional) password authentication, a framebuffer update, pointer and key input, wrong password refused.
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-vnc.$$.sock"
P=$((20000 + $$ % 20000))
export WS_SOCKET="$SOCK"
./wsd -t -g 400x300 -V $P > /dev/null 2>&1 &
W1=$!
WSD_VNC_PASSWORD=secret ./wsd -t -g 400x300 -V $((P + 1)) -s "$SOCK.2" > /dev/null 2>&1 &
W2=$!
trap 'kill $W1 $W2 2>/dev/null || true; rm -f "$SOCK" "$SOCK.2"' EXIT
sleep 1
python3 test/test_vnc.py $P
VNC_ZLIB=1 python3 test/test_vnc.py $P
VNC_BPP=16 python3 test/test_vnc.py $P
VNC_BPP=8 VNC_ZLIB=1 python3 test/test_vnc.py $P
if printf 01234567 | openssl enc -des-ecb -nopad -K 0000000000000000 -provider legacy -provider default >/dev/null 2>&1 || printf 01234567 | openssl enc -des-ecb -nopad -K 0000000000000000 >/dev/null 2>&1; then
	python3 test/test_vnc.py $((P + 1)) secret
	if python3 test/test_vnc.py $((P + 1)) wrong >/dev/null 2>&1; then echo "wrong password was accepted"; exit 1; fi
else
	echo "vnc: openssl has no DES here, password authentication not exercised"
fi
echo "vnc: ok"

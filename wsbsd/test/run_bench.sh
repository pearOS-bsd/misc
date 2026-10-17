#!/bin/sh
# Resource use and responsiveness of wsd: resident size idle / after a soak, CPU of the idle server, round trip latency of a cheap request,
# and the time of one composed 1080p frame (peak resident size of the compositor bench). Prints one line each; no pass/fail.
cd "$(dirname "$0")/.." || exit 1
CF="-O2 -std=c99 -D_DEFAULT_SOURCE -Iinclude"
C="src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c"
cc $CF -o bench_rpc test/bench_rpc.c $C -lm || exit 1
cc $CF -o bench_soak test/soak.c $C -lm || exit 1
cc $CF -o bench_compose test/bench_compose.c src/compositor_sw.c src/blur.c src/shadow.c src/region.c src/buffer.c src/evrec.c src/ipc.c src/server.c -lm || exit 1
export WS_SOCKET=/tmp/wsd-bench.$$.sock
./wsd -t -g 1920x1080 >/dev/null 2>&1 & W=$!
sleep 1
echo "idle: rss $(ps -o rss= -p $W) KB"
sleep 3; echo "idle 3 s later: cpu time $(ps -o time= -p $W)"
./bench_rpc
./bench_soak 1000 $W | tail -1
kill $W 2>/dev/null; wait $W 2>/dev/null
./bench_compose
rm -f bench_rpc bench_soak bench_compose "$WS_SOCKET"

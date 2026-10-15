#!/bin/sh
# Dumps every SkyLight request (id, bits, size, body words) a real Cocoa app sends, to replay them against the real server (replay.scen generation) and to learn real argument values.
cd "$(dirname "$0")"
mkdir -p ../lab-out
clang -fobjc-arc -o ../lab-out/appkit_app appkit_app.m -framework Cocoa 2>&1 | head -20
cat > ../lab-out/dumpall.d <<'EOD'
#pragma D option quiet
#pragma D option bufsize=64m
mach_trap::mach_msg2_trap:entry /execname == "appkit_app" && (((arg4 >> 32) >= 29000 && (arg4 >> 32) < 29042) || ((arg4 >> 32) >= 30000 && (arg4 >> 32) < 30647) || ((arg4 >> 32) >= 32000 && (arg4 >> 32) < 32074) || ((arg4 >> 32) >= 33000 && (arg4 >> 32) < 33029) || ((arg4 >> 32) >= 34000 && (arg4 >> 32) < 34010))/ {
  this->p = (uint32_t *)copyin(arg0, 256);
  this->sz = (arg2 >> 32);
  printf("id=%d bits=%08x size=%d:", arg4 >> 32, this->p[0], this->sz);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x", this->p[6], this->p[7], this->p[8], this->p[9], this->p[10], this->p[11], this->p[12], this->p[13]);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x", this->p[14], this->p[15], this->p[16], this->p[17], this->p[18], this->p[19], this->p[20], this->p[21]);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x", this->p[22], this->p[23], this->p[24], this->p[25], this->p[26], this->p[27], this->p[28], this->p[29]);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x\n", this->p[30], this->p[31], this->p[32], this->p[33], this->p[34], this->p[35], this->p[36], this->p[37]);
}
EOD
(sleep 1; ../lab-out/appkit_app > ../lab-out/app.log 2>&1) &
sudo dtrace -s ../lab-out/dumpall.d -c "sleep 8" > ../lab-out/dump_all.txt 2>&1
wait
wc -l ../lab-out/dump_all.txt

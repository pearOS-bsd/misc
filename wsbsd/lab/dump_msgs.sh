#!/bin/sh
# Dumps the first bytes of selected requests a real Cocoa app sends (dtrace on mach_msg2_trap): real argument values for the routines under study.
cd "$(dirname "$0")"
mkdir -p ../lab-out
clang -fobjc-arc -o ../lab-out/appkit_app appkit_app.m -framework Cocoa 2>&1 | head -20
cat > ../lab-out/dump.d <<'EOD'
#pragma D option quiet
mach_trap::mach_msg2_trap:entry /execname == "appkit_app" && ((arg4 >> 32) == 30283 || (arg4 >> 32) == 30119 || (arg4 >> 32) == 30378 || (arg4 >> 32) == 30379 || (arg4 >> 32) == 30048 || (arg4 >> 32) == 30025 || (arg4 >> 32) == 30393 || (arg4 >> 32) == 30399 || (arg4 >> 32) == 30445 || (arg4 >> 32) == 30251 || (arg4 >> 32) == 30208 || (arg4 >> 32) == 30209 || (arg4 >> 32) == 30181 || (arg4 >> 32) == 30182 || (arg4 >> 32) == 30270 || (arg4 >> 32) == 30272 || (arg4 >> 32) == 30325 || (arg4 >> 32) == 30370 || (arg4 >> 32) == 30373)/ {
  this->p = (uint32_t *)copyin(arg0, 160);
  printf("id=%d size=%d:", arg4 >> 32, arg2 >> 32);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x", this->p[6], this->p[7], this->p[8], this->p[9], this->p[10], this->p[11], this->p[12], this->p[13]);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x", this->p[14], this->p[15], this->p[16], this->p[17], this->p[18], this->p[19], this->p[20], this->p[21]);
  printf(" %08x %08x %08x %08x\n", this->p[22], this->p[23], this->p[24], this->p[25]);
}
EOD
(sleep 1; ../lab-out/appkit_app > ../lab-out/app.log 2>&1) &
sudo dtrace -s ../lab-out/dump.d -c "sleep 8" > ../lab-out/dump_msgs.txt 2>&1
wait
sort -t= -k2 -n ../lab-out/dump_msgs.txt | head -150

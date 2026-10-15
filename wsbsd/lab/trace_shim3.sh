#!/bin/sh
# Which wire ids does each SLS call of the shared program use? (dtrace on the real system, in order)
cd "$(dirname "$0")"
mkdir -p ../lab-out
cc -g -o ../lab-out/shim_api3 shim_api3.c 2>&1 | head -5
cat > ../lab-out/ids.d <<'EOD'
#pragma D option quiet
mach_trap::mach_msg2_trap:entry /execname == "shim_api3" && (((arg4 >> 32) >= 29000 && (arg4 >> 32) < 29042) || ((arg4 >> 32) >= 30000 && (arg4 >> 32) < 30647) || ((arg4 >> 32) >= 32000 && (arg4 >> 32) < 32074) || ((arg4 >> 32) >= 33000 && (arg4 >> 32) < 33029) || ((arg4 >> 32) >= 34000 && (arg4 >> 32) < 34010))/ {
  this->p = (uint32_t *)copyin(arg0, 96);
  printf("id=%d size=%d:", arg4 >> 32, arg2 >> 32);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x\n", this->p[6], this->p[7], this->p[8], this->p[9], this->p[10], this->p[11], this->p[12], this->p[13]);
}
EOD
sudo dtrace -s ../lab-out/ids.d -c ../lab-out/shim_api3 2>&1 | cut -c1-200

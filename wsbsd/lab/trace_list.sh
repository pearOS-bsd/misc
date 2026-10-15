#!/bin/sh
# Which wire ids does each SLS call of the shared program use? (dtrace on the real system, in order)
cd "$(dirname "$0")"
mkdir -p ../lab-out
cc -g -o ../lab-out/shim_api3 shim_api3.c 2>&1 | head -5
cat > ../lab-out/ids.d <<'EOD'
#pragma D option quiet
mach_trap::mach_msg2_trap:entry /execname == "shim_api3" && ((arg4 >> 32) == 30066 || (arg4 >> 32) == 30067 || (arg4 >> 32) == 30061)/ {
  this->p = (uint32_t *)copyin(arg0, 160);
  printf("id=%d size=%d:", arg4 >> 32, arg2 >> 32);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x", this->p[6], this->p[7], this->p[8], this->p[9], this->p[10], this->p[11], this->p[12], this->p[13], this->p[14], this->p[15], this->p[16], this->p[17]);
  printf(" %08x %08x %08x %08x %08x %08x %08x %08x\n", this->p[18], this->p[19], this->p[20], this->p[21], this->p[22], this->p[23], this->p[24], this->p[25]);
}
EOD
sudo dtrace -s ../lab-out/ids.d -c ../lab-out/shim_api3 2>&1 | cut -c1-200

#!/bin/sh
# Runs the Cocoa app under dtrace and counts the Mach messages it sends (by msgh_id): the demand list for wsd.
cd "$(dirname "$0")"
sudo dtrace -l -P mach_trap 2>&1 | grep -i "msg" | head
mkdir -p ../lab-out
clang -fobjc-arc -o ../lab-out/appkit_app appkit_app.m -framework Cocoa 2>&1 | head -20
cat > ../lab-out/trace.d <<'EOD'
mach_trap::mach_msg2_trap:entry /execname == "appkit_app"/ { this->h = (uint32_t *)copyin(arg0, 32); this->id = arg4 >> 32; this->rp = this->h[2]; @ports[this->id, this->rp] = count(); }
END { printa("id=%d remote=%d n=%@d\n", @ports); }
EOD
(sleep 1; ../lab-out/appkit_app > ../lab-out/app.log 2>&1) &
sudo dtrace -q -s ../lab-out/trace.d -c "sleep 8" > ../lab-out/trace_appkit.txt 2>&1
wait
cat ../lab-out/trace_appkit.txt | sort | head -400

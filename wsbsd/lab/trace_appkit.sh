#!/bin/sh
# Runs the Cocoa app under dtrace and counts the Mach messages it sends (by msgh_id): the demand list for wsd.
cd "$(dirname "$0")"
sudo dtrace -l -P mach_trap 2>&1 | grep -i "msg" | head
mkdir -p ../lab-out
clang -fobjc-arc -o ../lab-out/appkit_app appkit_app.m -framework Cocoa 2>&1 | head -20
cat > ../lab-out/trace.d <<'EOD'
mach_trap::mach_msg2_trap:entry /execname == "appkit_app"/ { @ids2[(arg4 >> 32)] = count(); @sz2[(arg4 >> 32), (arg2 >> 32)] = count(); }
mach_trap::mach_msg_trap:entry /execname == "appkit_app"/ { this->h = (uint32_t *)copyin(arg0, 24); @ids1[this->h[5]] = count(); }
mach_trap::mach_msg_overwrite_trap:entry /execname == "appkit_app"/ { this->h = (uint32_t *)copyin(arg0, 24); @ids3[this->h[5]] = count(); }
END { printa("msg2 id=%d n=%@d\n", @ids2); printa("msg2 id=%d size=%d n=%@d\n", @sz2); printa("msg id=%d n=%@d\n", @ids1); printa("overwrite id=%d n=%@d\n", @ids3); }
EOD
(sleep 1; ../lab-out/appkit_app > ../lab-out/app.log 2>&1) &
sudo dtrace -q -s ../lab-out/trace.d -c "sleep 8" > ../lab-out/trace_appkit.txt 2>&1
wait
cat ../lab-out/trace_appkit.txt | sort | head -400

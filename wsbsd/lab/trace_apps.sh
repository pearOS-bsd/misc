#!/bin/sh
# Traces the Mach messages (by msgh_id) that real Cocoa apps send while they start and sit idle: the demand list for wsd beyond the one-window test app.
cd "$(dirname "$0")"
mkdir -p ../lab-out
for APP in TextEdit Calculator Stickies; do
	EXE="$APP"
	cat > ../lab-out/trace_$APP.d <<EOD
mach_trap::mach_msg2_trap:entry /execname == "$EXE"/ { @ids2[(arg4 >> 32)] = count(); }
mach_trap::mach_msg_trap:entry /execname == "$EXE"/ { this->h = (uint32_t *)copyin(arg0, 24); @ids1[this->h[5]] = count(); }
mach_trap::mach_msg_overwrite_trap:entry /execname == "$EXE"/ { this->h = (uint32_t *)copyin(arg0, 24); @ids3[this->h[5]] = count(); }
END { printa("msg2 id=%d n=%@d\n", @ids2); printa("msg id=%d n=%@d\n", @ids1); printa("overwrite id=%d n=%@d\n", @ids3); }
EOD
	(sleep 2; open -n -a "$APP"; sleep 4) &
	sudo dtrace -q -s ../lab-out/trace_$APP.d -c "sleep 12" > ../lab-out/trace_$APP.txt 2>&1
	wait
	pkill -x "$APP" 2>/dev/null
	echo "=== $APP: $(grep -c . ../lab-out/trace_$APP.txt) lines"
done
for APP in TextEdit Calculator Stickies; do echo "## $APP"; sort ../lab-out/trace_$APP.txt | head -150; done

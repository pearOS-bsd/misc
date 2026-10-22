#!/bin/sh
# builds CoreWLAN and one probe (argument: tools/cwprobe/NAME.m) on the FreeBSD VM, runs it: ssh ... 'sh -s NAME' < tools/cwprobe/run_bsd.sh
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh; cd /root/wsbsd; CW=/tmp/cwout; sh sdk/build-corewlan.sh $CW 2>&1 | grep -E "error" | head
CWL=$CW/System/Library/Frameworks/CoreWLAN.framework/Versions/A; CWF=$CW/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A
clang -x objective-c -fblocks -fobjc-arc -w -Isdk/include $(gnustep-config --objc-flags) tools/cwprobe/$1.m -o /tmp/probe_$1 $(gnustep-config --base-libs) -L$CWL -L$CWF -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,$CWL -Wl,-rpath,$CWF -L/usr/local/lib -lffi -ldispatch 2>&1 | grep error
LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib /tmp/probe_$1 2>&1

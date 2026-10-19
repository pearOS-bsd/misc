#!/bin/sh
# AppKit (GNUstep gui) on wsd: builds libs-back with the "wsd" display server (appkit/back-wsd) in place of the headless one, then runs
# AppKit programs against a live wsd and takes screenshots (hello, Sudoku, Gorm, Terminal with neofetch).
. "$(dirname "$0")/gnustep-setup.sh"
cd "$WS"
cc -o hello appkit/hello.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | tail -15
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsshot tools/wsshot.c /tmp/wsc/libwsclient.a -lm
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsclick tools/wsclick.c /tmp/wsc/libwsclient.a -lm
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsdrag tools/wsdrag.c /tmp/wsc/libwsclient.a -lm
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wskey tools/wskey.c /tmp/wsc/libwsclient.a -lm
gmake wsd 2>&1 | tail -2
export WS_SOCKET=/tmp/wsd-appkit.sock
export XDG_CURRENT_DESKTOP=Aqua XDG_SESSION_DESKTOP=Aqua XDG_SESSION_TYPE=wsd      # what wsstart exports: neofetch shows DE: Aqua
./wsd -t -g 1280x800 >/tmp/wsd.log 2>&1 &
WP=$!
sleep 1
cc -fobjc-arc -o test_tracking test/test_tracking.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | grep error
timeout 60 ./test_tracking 2>&1 | grep -v 'time zone' | tail -5 | tee /tmp/tracking.log; grep -q 'tracking ok' /tmp/tracking.log || { echo 'TRACKING TEST FAILED'; exit 1; }
cc -fobjc-arc -o test_menuitem test/test_menuitem.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | grep error
timeout 60 ./test_menuitem 2>&1 | grep -v 'time zone' | tail -5 | tee /tmp/menuitem.log; grep -q 'menuitem ok' /tmp/menuitem.log || { echo 'MENUITEM TEST FAILED'; exit 1; }
(WSD_DEBUG=1 timeout 60 lldb -b -o 'run -HelloSeconds 18' -o 'bt' -o 'quit' -- ./hello >/tmp/hello.log 2>&1) &
HP=$!
sleep 4
./wsshot appkit.ppm; python3 tools/ppm2png.py appkit.ppm appkit.png
./wsclick 180 554
sleep 1
./wsshot appkit-click.ppm; python3 tools/ppm2png.py appkit-click.ppm appkit-click.png
./wsclick 220 608
./wskey 0 11 8
sleep 1
./wsshot appkit-key.ppm; python3 tools/ppm2png.py appkit-key.ppm appkit-key.png
./wsdrag 270 488 700 200
sleep 1
./wsshot appkit-drag.ppm; python3 tools/ppm2png.py appkit-drag.ppm appkit-drag.png
i=0; until grep -q 'frame after resize' /tmp/hello.log || [ $i -ge 30 ]; do sleep 1; i=$((i+1)); done; sleep 1
./wsshot appkit-resize.ppm; python3 tools/ppm2png.py appkit-resize.ppm appkit-resize.png
wait $HP
# a real, unmodified GNUstep application from the package repository
APP=$(find /usr/local/GNUstep -maxdepth 4 -name 'Sudoku.app' 2>/dev/null | head -1)
echo "sudoku app: $APP"
if [ -n "$APP" ]; then
	BIN="$APP/Sudoku"
	(WSD_DEBUG=1 timeout 40 lldb -b -o 'run' -o 'bt' -o 'quit' -- "$BIN" >/tmp/sudoku.log 2>&1) &
	SP=$!
	sleep 12
	./wsshot sudoku.ppm; python3 tools/ppm2png.py sudoku.ppm sudoku.png
	./wsclick 640 400; ./wsclick 20 700; sleep 1
	./wsshot sudoku-cell.ppm; python3 tools/ppm2png.py sudoku-cell.ppm sudoku-cell.png
	./wsclick 38 71; sleep 1
	./wsshot sudoku-menu.ppm; python3 tools/ppm2png.py sudoku-menu.ppm sudoku-menu.png
	kill $SP 2>/dev/null; pkill -f Sudoku 2>/dev/null
	grep -v '^(lldb)\|warning\|wsd-back: \(titlewindow\|setinput\|flush\|commit\|order\|ws_win\)' /tmp/sudoku.log | tail -30
fi
# a larger application built from source: Gorm, GNUstep's interface builder (panels, palettes, inspectors)
(cd /tmp/gs && git clone --depth 1 https://github.com/gnustep/apps-gorm gorm 2>&1 | tail -1 && cd gorm && grep -rl 6Formatters --include=GNUmakefile . | head -3 | xargs -I{} sed -i '' 's/6Formatters//' {}; gmake -j2 2>&1 | grep -E "error|Error " | head -8; gmake install 2>&1 | tail -2)
GAPP=$(find /usr/local/GNUstep /tmp/gs/gorm -maxdepth 5 -name 'Gorm.app' -type d 2>/dev/null | head -1)
echo "gorm app: $GAPP"
if [ -n "$GAPP" ]; then
	(WSD_DEBUG=1 timeout 60 lldb -b -o 'run' -o 'bt' -o 'quit' -- "$GAPP/Gorm" >/tmp/gorm.log 2>&1) &
	GP=$!
	sleep 25
	./wsshot gorm.ppm; python3 tools/ppm2png.py gorm.ppm gorm.png
	./wsclick 38 51; sleep 1
	./wsshot gorm-menu.ppm; python3 tools/ppm2png.py gorm-menu.ppm gorm-menu.png
	./wsclick 150 72; sleep 5
	./wsshot gorm-doc.ppm; python3 tools/ppm2png.py gorm-doc.ppm gorm-doc.png
	kill $GP 2>/dev/null; pkill -f Gorm 2>/dev/null
	grep -v '^(lldb)\|warning\|wsd-back: ' /tmp/gorm.log | tail -25
fi
# Terminal (terminal/): a terminal emulator written against the public Cocoa API, built with GNUstep and run on wsd with some shell output
TD="$WS/../terminal"
if [ -d "$TD" ]; then
	(cd "$TD" && make test 2>&1 | tail -2 && cc -o Terminal-gnustep src/vt.c src/pty.c src/TermView.m src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) -lutil 2>&1 | grep -E "error|undefined" | head -15)
	if [ -x "$TD/Terminal-gnustep" ]; then
		cat > /tmp/term-input.txt <<'EOT'
echo hello from the shell; printf '\033[1;31mred\033[0m \033[38;5;33mblue\033[0m\n'; clear; neofetch
EOT
		rm -f /tmp/terminal-dump.txt
		(TERMINAL_COLS=110 TERMINAL_ROWS=30 TERMINAL_EXIT_AFTER=26 TERMINAL_DUMP=/tmp/terminal-dump.txt TERMINAL_INITIAL_INPUT="$(cat /tmp/term-input.txt)
" WSD_DEBUG=1 timeout 40 lldb -b -o 'run' -o 'bt' -o 'quit' -- "$TD/Terminal-gnustep" >/tmp/terminal.log 2>&1) &
		TP=$!
		sleep 14
		{ echo "TERMINAL: screenshot"; ./wsshot terminal.ppm; echo "wsshot rc=$?"; python3 tools/ppm2png.py terminal.ppm terminal.png; echo "ppm2png rc=$?"; } >> /tmp/terminal-ci.txt 2>&1
		./wskey 0 0 8; sleep 1
		./wsshot terminal-key.ppm; python3 tools/ppm2png.py terminal-key.ppm terminal-key.png
		ls -l terminal*.png >> /tmp/terminal-ci.txt 2>&1
		i=0; while kill -0 $TP 2>/dev/null && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done          # the application quits itself after TERMINAL_EXIT_AFTER seconds, writing its screen text
		kill $TP 2>/dev/null; pkill -f Terminal-gnustep 2>/dev/null
		{ echo "TERMINAL SCREEN TEXT:"; cat /tmp/terminal-dump.txt 2>&1 | head -30; } >> /tmp/terminal-ci.txt 2>&1
		if grep -q 'OS:' /tmp/terminal-dump.txt 2>/dev/null && grep -q 'Uptime' /tmp/terminal-dump.txt; then TERMINAL_OK=1; else TERMINAL_OK=0; fi
		if grep -q 'DE: Aqua' /tmp/terminal-dump.txt 2>/dev/null; then echo 'neofetch DE: Aqua (ok)'; else echo 'neofetch did not print DE: Aqua'; fi
		{ echo "TERMINAL LOG:"; grep -v '^(lldb)' /tmp/terminal.log | grep -v 'wsd-back: \(titlewindow\|setinput\|flush\|commit\|order\|ws_win\|receivedEvent\|event type\)' | tail -40; } >> /tmp/terminal-ci.txt 2>&1
	fi
fi
fc-list 2>/dev/null | grep -i "inter" | head -3 | sed 's/^/FONT: /'
# Terminal parity run: the same fixed session as terminal/tools/macshot.sh (sh, prompt "$ ", two lines), screenshotted for the side-by-side with macOS
if [ -x "$TD/Terminal-gnustep" ]; then
	(SHELL=/bin/sh TERMINAL_COLS=80 TERMINAL_ROWS=24 TERMINAL_EXIT_AFTER=10 TERMINAL_INITIAL_INPUT="PS1='\$ '; clear; echo hello from the shell; printf '\\033[1;31mred\\033[0m \\033[38;5;33mblue\\033[0m\\n'
" timeout 20 "$TD/Terminal-gnustep" >/tmp/terminal-parity.log 2>&1) &
	TPP=$!; sleep 5; ./wsshot terminal-parity.ppm && python3 tools/ppm2png.py terminal-parity.ppm terminal-parity.png
	i=0; while kill -0 $TPP 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i+1)); done; pkill -f Terminal-gnustep 2>/dev/null
fi
# Keyboard Setup Assistant (ksa/): the same Cocoa sources as on macOS, run on wsd; every pane is screenshotted and the Shift-key flow is checked
KD="$WS/../ksa"
if [ -d "$KD" ]; then
	(cd "$KD" && cc -o KeyboardSetupAssistant-gnustep src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | grep -E "error|undefined" | head -20)
	if [ -x "$KD/KeyboardSetupAssistant-gnustep" ]; then
		for p in 0 1 2 3; do
			(WSD_DUMP_IMAGES=/tmp WSD_WINDOW_BG=27,36,43 KSA_PANE=$p KSA_EXIT_AFTER=9 timeout 20 "$KD/KeyboardSetupAssistant-gnustep" >/tmp/ksa$p.log 2>&1) &
			KP=$!; sleep 5
			./wsshot ksa-pane$p.ppm && python3 tools/ppm2png.py ksa-pane$p.ppm ksa-pane$p.png
			i=0; while kill -0 $KP 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i+1)); done; pkill -f KeyboardSetupAssistant-gnustep 2>/dev/null
		done
		rm -f /tmp/ksa-out.txt
		(KSA_PANE=1 KSA_SCRIPT="key:6,key:44,done" KSA_OUTPUT=/tmp/ksa-out.txt KSA_EXIT_AFTER=12 timeout 20 "$KD/KeyboardSetupAssistant-gnustep" >/tmp/ksa-flow.log 2>&1) &
		KP=$!; i=0; while kill -0 $KP 2>/dev/null && [ $i -lt 20 ]; do sleep 1; i=$((i+1)); done
		ls -l /tmp/wsd-*.tiff 2>&1 | head; for t in /tmp/wsd-*.tiff; do echo "TIFF $t $(wc -c < $t)"; done; echo '=== KSA ==='; cat /tmp/ksa-flow.log | grep -v wsd-back | tail -12; echo "ksa output: $(cat /tmp/ksa-out.txt 2>&1)"
		grep -qx ANSI /tmp/ksa-out.txt 2>/dev/null && echo 'KSA flow ok' || echo 'KSA flow FAILED'
	fi
fi
# UI gallery (uitest/): every standard control, the same Cocoa source as on macOS; screenshot + control manifest for the per-control comparison
UD="$WS/../uitest"
if [ -d "$UD" ]; then
	(cd "$UD" && cc -o UITest-gnustep src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | grep -E "error|undefined" | head -20)
	if [ -x "$UD/UITest-gnustep" ]; then
		(WSD_WINDOW_BG=27,36,43 UI_EXIT_AFTER=9 timeout 20 "$UD/UITest-gnustep" >/tmp/uitest-manifest.txt 2>/tmp/uitest.log) &
		UP=$!; sleep 5
		./wsshot uitest.ppm && python3 tools/ppm2png.py uitest.ppm uitest.png; grep '^CTRL' /tmp/uitest-manifest.txt > uitest-manifest.txt
		python3 - <<'PY' || UITEST_BLANK=1
import sys
d=open('uitest.ppm','rb').read()
body=d[-1280*800*3:]
print('uitest screenshot: %d distinct bytes' % len(set(body[::97])))
sys.exit(0 if len(set(body[::97]))>40 else 1)
PY
		i=0; while kill -0 $UP 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i+1)); done; pkill -f UITest-gnustep 2>/dev/null
		(WSD_APPEARANCE=light UI_EXIT_AFTER=9 timeout 20 "$UD/UITest-gnustep" >/dev/null 2>/tmp/uitest-light.log) &
		UP=$!; sleep 5; ./wsshot uitest-light.ppm && python3 tools/ppm2png.py uitest-light.ppm uitest-light.png
		i=0; while kill -0 $UP 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i+1)); done; pkill -f UITest-gnustep 2>/dev/null
		for MODE in menu alert vibrancy; do
			(UI_MODE=$MODE WSD_WINDOW_BG=27,36,43 UI_EXIT_AFTER=9 timeout 20 "$UD/UITest-gnustep" >/dev/null 2>/tmp/uitest-$MODE.log) &
			UP=$!; sleep 5; ./wsshot uitest-$MODE.ppm && python3 tools/ppm2png.py uitest-$MODE.ppm uitest-$MODE.png
			i=0; while kill -0 $UP 2>/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i+1)); done; pkill -f UITest-gnustep 2>/dev/null
		done
		echo "=== UITEST vibrancy log ==="; grep -v "wsd-back: " /tmp/uitest-vibrancy.log | tail -12
		echo "=== UITEST ==="; wc -l uitest-manifest.txt; grep -v wsd-back /tmp/uitest.log | tail -5
	fi
fi
echo '=== SDK TESTS (compat layer) ==='; sh "$WS/ci/sdk-tests.sh" 2>&1 | tee sdk-tests.log | tail -30
kill $WP 2>/dev/null
echo '=== OSS APP PROBE ==='; sh "$WS/ci/oss-probe.sh" 2>&1 | tee oss-probe.log | tail -80
grep -v '^(lldb)\|warning\|wsd-back: \(titlewindow\|setinput\|flush\|commit\|order\|ws_win\)' /tmp/hello.log | tail -40; tail -5 /tmp/wsd.log
ls -l appkit.png
echo '=== TERMINAL (terminal/) ==='; cat /tmp/terminal-ci.txt 2>/dev/null
grep -q 'SDK TEST .*FAILED\|did not build' sdk-tests.log 2>/dev/null && { echo '=== sdk-tests.log ==='; tail -60 sdk-tests.log | cut -c1-240; echo 'SDK TESTS FAILED'; exit 1; }
[ "${UITEST_BLANK:-0}" = 0 ] || { echo 'UITEST CHECK FAILED: the gallery screenshot is blank (the app or the backend did not build)'; exit 1; }
[ "${TERMINAL_OK:-1}" = 1 ] || { echo 'TERMINAL CHECK FAILED: neofetch output is not on the terminal screen'; exit 1; }

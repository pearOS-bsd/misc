/* Keyboard Setup Assistant: the flow recovered from Apple's KeyboardSetupAssistant (macOS 27) with REA.
 *  panes: 0 introduction, 1 "press the key to the right of the left Shift", 2 "...to the left of the right Shift", 3 "select the keyboard type"
 *  keyboard types: 0 JIS, 1 ISO, 2 ISO (Mac), 3 ANSI, 4 unknown
 *  key codes (kVK_*): 0x0a ISO section -> ISO, 0x32 grave -> ISO (Mac), 0x2c slash -> ANSI, 0x5e JIS underscore -> JIS; the left pane accepts {0x0a, 0x32, 0x06}, a Z (0x06) is ambiguous (ANSI or JIS) and goes on to the right pane,
 *  Cmd+Q is ignored; the pane texts are Apple's English strings. */
#import <Cocoa/Cocoa.h>

enum { KSATypeJIS = 0, KSATypeISO = 1, KSATypeISOMac = 2, KSATypeANSI = 3, KSATypeUnknown = 4 };

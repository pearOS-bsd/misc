/* A GNUstep theme that gives windows the macOS look (window decorations measured on a real macOS 27 / AppKit window; see docs/UI-MAC.md) */
#import <GNUstepGUI/GSTheme.h>
#import <GNUstepGUI/GSWindowDecorationView.h>

void WsdApplyMacPalette(void);                      /* sets the NSColor system colours of the macOS palette */

@interface WsdMacTheme : GSTheme
@end
@interface WsdMacTheme (Controls)
@end

/* the decoration view: 32 pt title bar, traffic lights 14 pt at x = 9, 32, 55, the title leading-aligned at x = 82 in the semibold 13 pt face, no side or bottom border (the window server draws the shadow, the rounded corners and the 1 px rim) */
@interface WsdMacDecorationView : GSStandardWindowDecorationView
@end

#import <AppKit/AppKit.h>
#include <sys/types.h>
#include "vt.h"

/* A terminal view: draws a vt screen, sends keystrokes to the pty, resizes the pty with the view. */
@interface TermView : NSView
{
	vt *term; int master; pid_t child;
	NSFont *font, *boldFont; CGFloat cellW, cellH, ascent;
	NSTimer *pump; uint32_t drawnGen; BOOL exited;
	int scrollOffset;                      /* lines scrolled back into history */
	int selStartX, selStartY, selEndX, selEndY; BOOL hasSel;
}
- (instancetype)initWithShell:(NSString *)shell;
- (NSSize)idealSizeForCols:(int)cols rows:(int)rows;
- (NSString *)titleString;
- (BOOL)childExited;
- (void)writeString:(NSString *)s;                         /* sends text to the shell as if typed */
- (BOOL)dumpScreenToFile:(NSString *)path;                 /* the visible text, one line per row (for automated checks) */
- (void)paste:(id)sender;
- (void)copy:(id)sender;
@end

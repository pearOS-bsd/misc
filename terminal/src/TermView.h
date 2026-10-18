#import <AppKit/AppKit.h>
#include <sys/types.h>
#include "vt.h"
#import "TermProfile.h"

/* A terminal view: draws a vt screen with a profile's colours and font, sends keystrokes to the pty (mouse reports, bracketed paste, focus events), selection by character / word / line,
 * the find highlights, scrolling and clearing commands of the Terminal menus. */
@interface TermView : NSView
{
	vt *term; int master; pid_t child; NSString *command;
	TermProfile *profile; CGFloat fontSize; NSFont *font, *boldFont; CGFloat cellW, cellH, ascent;
	NSTimer *pump, *blinkTimer; uint32_t drawnGen; BOOL exited, blinkOn, active;
	int scrollOffset;                      /* lines scrolled back into history */
	int selStartX, selStartY, selEndX, selEndY; BOOL hasSel; int clickCount;
	NSString *findQuery; BOOL findCase;    /* matches are highlighted while set */
	id delegate; NSString *customTitle;
	NSMutableArray *marks, *bookmarks;     /* absolute line numbers (vt_scrolled + row) of the marks and bookmarks the user set */
}
+ (void)setAutoMarkPrompts:(BOOL)b; + (BOOL)autoMarkPrompts; + (void)setShowMarks:(BOOL)b; + (BOOL)showMarks;
- (id)delegate; - (void)setDelegate:(id)d;                /* told about title changes and the end of the shell: -termViewChanged: / -termViewExited: */
- (TermProfile *)profile;
- (instancetype)initWithProfile:(TermProfile *)p command:(NSString *)cmd;
- (void)applyProfile:(TermProfile *)p;
- (NSSize)idealSizeForCols:(int)cols rows:(int)rows;
- (int)cols; - (int)rows;
- (NSString *)titleString;                                 /* the custom title when Edit Title set one, else the program's (OSC) title */
- (void)setCustomTitle:(NSString *)t;
- (BOOL)childExited;
- (void)setActive:(BOOL)a;                 /* the window is key and this is the front tab: the cursor is solid */
- (void)writeString:(NSString *)s;                         /* sends text to the shell as if typed */
- (BOOL)dumpScreenToFile:(NSString *)path;                 /* the visible text, one line per row (for automated checks) */
- (pid_t)childPid; - (NSString *)ttyName;                  /* for the Inspector */
- (NSString *)allText;                                     /* scrollback and screen */
- (NSString *)selectedText;
/* menu actions */
- (void)paste:(id)sender; - (void)copy:(id)sender; - (void)selectAll:(id)sender;
- (void)clearScreen:(id)sender; - (void)clearScrollback:(id)sender; - (void)clearToStart:(id)sender; - (void)resetTerminal:(id)sender; - (void)hardResetTerminal:(id)sender;
- (void)biggerFont:(id)sender; - (void)smallerFont:(id)sender; - (void)defaultFontSize:(id)sender;
- (void)scrollToTop:(id)sender; - (void)scrollToBottom:(id)sender; - (void)scrollPageUp:(id)sender; - (void)scrollPageDown:(id)sender; - (void)scrollLineUp:(id)sender; - (void)scrollLineDown:(id)sender;
- (BOOL)findText:(NSString *)s forward:(BOOL)fwd caseSensitive:(BOOL)cs;   /* from the current selection; selects and scrolls to the match */
- (void)setFindHighlight:(NSString *)s;
- (void)markLine:(id)sender; - (void)unmarkLine:(id)sender; - (void)markAsBookmark:(id)sender; - (void)insertBookmark:(id)sender;
- (void)jumpToPreviousMark:(id)sender; - (void)jumpToNextMark:(id)sender; - (void)jumpToPreviousBookmark:(id)sender; - (void)jumpToNextBookmark:(id)sender;
- (void)clearToPreviousMark:(id)sender;
@end

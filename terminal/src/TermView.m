#import "TermView.h"
#include "pty.h"
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

static void vt_reply(void *ctx, const char *d, size_t n) { int fd = *(int *)ctx; if (fd >= 0) (void)write(fd, d, n); }

@implementation TermView

- (instancetype)initWithShell:(NSString *)shell
{
	self = [super initWithFrame:NSMakeRect(0, 0, 640, 384)];
	if (!self) return nil;
	font = [[NSFont userFixedPitchFontOfSize:13] retain];
	boldFont = [[NSFont boldSystemFontOfSize:13] retain];
	if ([[boldFont fontName] rangeOfString:@"Mono"].location == NSNotFound) { [boldFont release]; boldFont = [font retain]; }
	cellW = [@"M" sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
	cellH = ceil([font ascender] - [font descender] + [font leading]);
	if (cellW < 4) cellW = 8; if (cellH < 8) cellH = 16;
	ascent = [font ascender];
	term = vt_new(80, 24, 5000);
	master = pty_spawn(shell ? [shell fileSystemRepresentation] : NULL, 80, 24, &child);
	vt_set_writer(term, vt_reply, &master);
	if (master < 0) { const char *m = "cannot start a shell\r\n"; vt_feed(term, m, strlen(m)); exited = YES; }
	pump = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 60 target:self selector:@selector(pump:) userInfo:nil repeats:YES] retain];
	return self;
}

- (void)dealloc
{
	[pump invalidate]; [pump release];
	if (master >= 0) close(master);
	if (child > 0) { kill(child, SIGHUP); waitpid(child, NULL, WNOHANG); }
	vt_free(term); [font release]; [boldFont release];
	[super dealloc];
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isOpaque { return YES; }
- (NSString *)titleString { const char *t = vt_title(term); return (t && *t) ? [NSString stringWithUTF8String:t] : @"Terminal"; }
- (BOOL)childExited { return exited; }
- (NSSize)idealSizeForCols:(int)cols rows:(int)rows { return NSMakeSize(cols * cellW, rows * cellH); }

- (void)pump:(NSTimer *)t
{
	(void)t;
	if (master >= 0) {
		char buf[65536]; int rounds = 0; ssize_t n;
		while (rounds++ < 8 && (n = read(master, buf, sizeof buf)) > 0) vt_feed(term, buf, (size_t)n);
		if (!exited) {
			int st; pid_t r = waitpid(child, &st, WNOHANG);
			if (r == child) { exited = YES; const char *m = "\r\n[Process completed]\r\n"; vt_feed(term, m, strlen(m)); }
		}
	}
	if (vt_dirty_gen(term) != drawnGen) { drawnGen = vt_dirty_gen(term); if (scrollOffset && !vt_alt_screen(term)) {} [self setNeedsDisplay:YES]; [[self window] setTitle:[self titleString]]; }
}

static NSColor *colour(uint32_t c, NSColor *dflt) { if (c == VT_DEFAULT_COLOR) return dflt; return [NSColor colorWithCalibratedRed:((c >> 16) & 0xff) / 255.0 green:((c >> 8) & 0xff) / 255.0 blue:(c & 0xff) / 255.0 alpha:1.0]; }

- (void)drawRect:(NSRect)dirty
{
	NSColor *defFg = [NSColor colorWithCalibratedWhite:0.92 alpha:1], *defBg = [NSColor colorWithCalibratedWhite:0.06 alpha:1];
	[defBg set]; NSRectFill(dirty);
	int cols = vt_cols(term), rows = vt_rows(term), curx, cury, curvis; vt_cursor(term, &curx, &cury, &curvis);
	int hist = vt_alt_screen(term) ? 0 : vt_scrollback_lines(term); if (scrollOffset > hist) scrollOffset = hist;
	for (int y = 0; y < rows; y++) {
		CGFloat py = y * cellH;
		if (py + cellH < dirty.origin.y || py > dirty.origin.y + dirty.size.height) continue;
		int srcline = y - scrollOffset;                                  /* < 0: a history line */
		for (int x = 0; x < cols; x++) {
			const vt_cell *c = srcline >= 0 ? vt_cell_at(term, x, srcline) : vt_scrollback_cell(term, x, -srcline - 1);
			if (!c) continue;
			uint32_t fg = c->fg, bg = c->bg; NSColor *f = colour(fg, defFg), *b = colour(bg, defBg);
			BOOL sel = hasSel && [self cellSelectedX:x y:y];
			if ((c->attr & VT_INVERSE) != 0 || sel) { NSColor *tmp = f; f = (bg == VT_DEFAULT_COLOR) ? defBg : b; b = tmp; if (bg == VT_DEFAULT_COLOR) b = defFg; }
			if (c->wide == 2) continue;
			CGFloat w = (c->wide == 1 ? 2 : 1) * cellW;
			if (bg != VT_DEFAULT_COLOR || (c->attr & VT_INVERSE) || sel) { [b set]; NSRectFill(NSMakeRect(x * cellW, py, w, cellH)); }
			if (c->ch != ' ' && c->ch != 0 && !(c->attr & VT_HIDDEN)) {
				unichar buf[2]; int n = 1;
				if (c->ch > 0xffff) { uint32_t v = c->ch - 0x10000; buf[0] = (unichar)(0xd800 + (v >> 10)); buf[1] = (unichar)(0xdc00 + (v & 0x3ff)); n = 2; } else buf[0] = (unichar)c->ch;
				NSString *s = [NSString stringWithCharacters:buf length:n];
				NSMutableDictionary *at = [NSMutableDictionary dictionaryWithObjectsAndKeys:((c->attr & VT_BOLD) ? boldFont : font), NSFontAttributeName, f, NSForegroundColorAttributeName, nil];
				if (c->attr & VT_UNDERLINE) [at setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
				[s drawAtPoint:NSMakePoint(x * cellW, py) withAttributes:at];
			}
		}
	}
	if (curvis && scrollOffset == 0 && !exited) {
		[[NSColor colorWithCalibratedWhite:0.85 alpha:0.7] set];
		NSRectFillUsingOperation(NSMakeRect(curx * cellW, cury * cellH, cellW, cellH), NSCompositeSourceOver);
	}
}

- (BOOL)cellSelectedX:(int)x y:(int)y
{
	int a = selStartY * 4096 + selStartX, b = selEndY * 4096 + selEndX, p = y * 4096 + x;
	if (a > b) { int t = a; a = b; b = t; }
	return p >= a && p <= b;
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	int cols = (int)(size.width / cellW), rows = (int)(size.height / cellH);
	if (cols < 2) cols = 2; if (rows < 1) rows = 1;
	if (cols != vt_cols(term) || rows != vt_rows(term)) { vt_resize(term, cols, rows); if (master >= 0) pty_set_size(master, cols, rows); [self setNeedsDisplay:YES]; }
}

- (void)writeString:(NSString *)s { if (master < 0 || exited) return; const char *u = [s UTF8String]; if (u) (void)write(master, u, strlen(u)); }

- (void)keyDown:(NSEvent *)e
{
	NSString *chars = [e characters]; if (![chars length]) return;
	unichar c = [chars characterAtIndex:0];
	NSUInteger mods = [e modifierFlags];
	BOOL app = vt_app_cursor_keys(term);
	const char *seq = NULL;
	switch (c) {
	case NSUpArrowFunctionKey: seq = app ? "\033OA" : "\033[A"; break;
	case NSDownArrowFunctionKey: seq = app ? "\033OB" : "\033[B"; break;
	case NSRightArrowFunctionKey: seq = app ? "\033OC" : "\033[C"; break;
	case NSLeftArrowFunctionKey: seq = app ? "\033OD" : "\033[D"; break;
	case NSHomeFunctionKey: seq = "\033[H"; break;
	case NSEndFunctionKey: seq = "\033[F"; break;
	case NSPageUpFunctionKey: seq = "\033[5~"; break;
	case NSPageDownFunctionKey: seq = "\033[6~"; break;
	case NSDeleteFunctionKey: seq = "\033[3~"; break;
	case NSF1FunctionKey: seq = "\033OP"; break; case NSF2FunctionKey: seq = "\033OQ"; break; case NSF3FunctionKey: seq = "\033OR"; break; case NSF4FunctionKey: seq = "\033OS"; break;
	case NSF5FunctionKey: seq = "\033[15~"; break; case NSF6FunctionKey: seq = "\033[17~"; break; case NSF7FunctionKey: seq = "\033[18~"; break; case NSF8FunctionKey: seq = "\033[19~"; break;
	case 0x7f: seq = "\x7f"; break;
	case 0x19: seq = "\033[Z"; break;                                      /* back tab */
	}
	scrollOffset = 0;
	if (seq) { if (master >= 0) (void)write(master, seq, strlen(seq)); return; }
	NSString *s = (mods & NSAlternateKeyMask) ? [@"\033" stringByAppendingString:[e charactersIgnoringModifiers]] : chars;   /* option sends escape */
	[self writeString:s];
}

- (void)scrollWheel:(NSEvent *)e
{
	if (vt_alt_screen(term)) { const char *s = [e deltaY] > 0 ? "\033[A\033[A\033[A" : "\033[B\033[B\033[B"; if (master >= 0) (void)write(master, s, strlen(s)); return; }
	scrollOffset += (int)([e deltaY] * 3) ; if (scrollOffset < 0) scrollOffset = 0; if (scrollOffset > vt_scrollback_lines(term)) scrollOffset = vt_scrollback_lines(term);
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; selStartX = selEndX = (int)(p.x / cellW); selStartY = selEndY = (int)(p.y / cellH); hasSel = NO; [self setNeedsDisplay:YES]; }
- (void)mouseDragged:(NSEvent *)e { NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; selEndX = (int)(p.x / cellW); selEndY = (int)(p.y / cellH); hasSel = YES; [self setNeedsDisplay:YES]; }

- (NSString *)selectedText
{
	if (!hasSel) return @"";
	int a = selStartY * 4096 + selStartX, b = selEndY * 4096 + selEndX; if (a > b) { int t = a; a = b; b = t; }
	NSMutableString *out = [NSMutableString string]; int lastY = -1;
	for (int y = a / 4096; y <= b / 4096 && y < vt_rows(term); y++) {
		NSMutableString *line = [NSMutableString string];
		for (int x = 0; x < vt_cols(term); x++) { int p = y * 4096 + x; if (p < a || p > b) continue; const vt_cell *c = vt_cell_at(term, x, y); if (!c || c->wide == 2) continue; unichar u = c->ch > 0xffff ? '?' : (unichar)c->ch; [line appendFormat:@"%C", (unichar)(u ? u : ' ')]; }
		while ([line hasSuffix:@" "]) [line deleteCharactersInRange:NSMakeRange([line length] - 1, 1)];
		if (lastY >= 0) [out appendString:@"\n"]; [out appendString:line]; lastY = y;
	}
	return out;
}

- (void)copy:(id)sender { (void)sender; NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil]; [pb setString:[self selectedText] forType:NSStringPboardType]; }
- (void)paste:(id)sender
{
	(void)sender; NSString *s = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]; if (!s) return;
	if (vt_bracketed_paste(term)) { [self writeString:@"\033[200~"]; [self writeString:s]; [self writeString:@"\033[201~"]; } else [self writeString:s];
}
- (void)selectAll:(id)sender { (void)sender; selStartX = 0; selStartY = 0; selEndX = vt_cols(term) - 1; selEndY = vt_rows(term) - 1; hasSel = YES; [self setNeedsDisplay:YES]; }
- (void)clearScreen:(id)sender { (void)sender; [self writeString:@"\014"]; }

@end

#import "TermView.h"
#include "pty.h"
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>

static void vt_reply(void *ctx, const char *d, size_t n) { int fd = *(int *)ctx; if (fd >= 0) (void)write(fd, d, n); }
static BOOL allowMouse = YES, optionAsMeta = YES;

@implementation TermView
- (id)delegate { return delegate; } - (void)setDelegate:(id)d { delegate = d; } - (TermProfile *)profile { return profile; }

+ (void)setAllowMouseReporting:(BOOL)b { allowMouse = b; }
+ (BOOL)allowMouseReporting { return allowMouse; }
+ (void)setOptionAsMeta:(BOOL)b { optionAsMeta = b; }
+ (BOOL)optionAsMeta { return optionAsMeta; }

- (instancetype)initWithProfile:(TermProfile *)p command:(NSString *)cmd
{
	self = [super initWithFrame:NSMakeRect(0, 0, 640, 384)];
	if (!self) return nil;
	command = [cmd retain];
	term = vt_new(80, 24, 10000);
	[self applyProfile:p ?: [TermProfile defaultProfile]];
	vt_resize(term, profile->cols, profile->rows);
	master = pty_spawn(command ? [command fileSystemRepresentation] : NULL, profile->cols, profile->rows, &child);
	vt_set_writer(term, vt_reply, &master);
	if (master < 0) { const char *m = "cannot start a shell\r\n"; vt_feed(term, m, strlen(m)); exited = YES; }
	pump = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 60 target:self selector:@selector(pump:) userInfo:nil repeats:YES] retain];
	blinkOn = YES; active = YES;
	return self;
}

- (void)applyProfile:(TermProfile *)p
{
	[profile release]; profile = [p retain];
	if (fontSize <= 0 || !font) fontSize = p->fontSize;
	[self rebuildFont];
	vt_set_ansi(term, p->ansi);
	[blinkTimer invalidate]; [blinkTimer release]; blinkTimer = nil;
	if (p->blink) blinkTimer = [[NSTimer scheduledTimerWithTimeInterval:0.55 target:self selector:@selector(blink:) userInfo:nil repeats:YES] retain];
	blinkOn = YES; [self setNeedsDisplay:YES];
}
- (void)blink:(NSTimer *)t { (void)t; blinkOn = !blinkOn; [self setNeedsDisplay:YES]; }

- (void)rebuildFont
{
	[font release]; [boldFont release];
	font = [[profile fontWithSize:fontSize bold:NO] retain]; boldFont = [[profile fontWithSize:fontSize bold:YES] retain];
	cellW = [@"M" sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width * profile->widthSpacing;
	cellH = ceil([font ascender] - [font descender] + [font leading]);
	if (cellW < 4) cellW = 8; if (cellH < 8) cellH = 16;
	ascent = [font ascender];
	NSSize sz = [self frame].size; if (sz.width > 0) [self setFrameSize:sz];
}

- (void)dealloc
{
	[pump invalidate]; [pump release]; [blinkTimer invalidate]; [blinkTimer release];
	if (master >= 0) close(master);
	if (child > 0) { kill(child, SIGHUP); waitpid(child, NULL, WNOHANG); }
	vt_free(term); [font release]; [boldFont release]; [profile release]; [command release]; [findQuery release];
	[super dealloc];
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isOpaque { return [profile->background alphaComponent] >= 0.999; }
- (NSString *)titleString { const char *t = vt_title(term); return (t && *t) ? [NSString stringWithUTF8String:t] : @"Terminal"; }
- (BOOL)childExited { return exited; }
- (int)cols { return vt_cols(term); } - (int)rows { return vt_rows(term); }
- (NSSize)idealSizeForCols:(int)cols rows:(int)rows { return NSMakeSize(cols * cellW, rows * cellH); }
- (void)setActive:(BOOL)a { active = a; if (vt_focus_events(term)) [self writeString:a ? @"\033[I" : @"\033[O"]; [self setNeedsDisplay:YES]; }

- (void)pump:(NSTimer *)t
{
	(void)t;
	if (master >= 0) {
		char buf[65536]; int rounds = 0; ssize_t n;
		while (rounds++ < 8 && (n = read(master, buf, sizeof buf)) > 0) vt_feed(term, buf, (size_t)n);
		if (!exited) {
			int st; pid_t r = waitpid(child, &st, WNOHANG);
			if (r == child) { exited = YES; const char *m = "\r\n[Process completed]\r\n"; vt_feed(term, m, strlen(m)); if ([delegate respondsToSelector:@selector(termViewExited:)]) [delegate termViewExited:self]; }
		}
	}
	if (vt_dirty_gen(term) != drawnGen) { drawnGen = vt_dirty_gen(term); [self setNeedsDisplay:YES]; if ([delegate respondsToSelector:@selector(termViewChanged:)]) [delegate termViewChanged:self]; }
}

static NSColor *rgbColor(uint32_t c) { return [NSColor colorWithCalibratedRed:((c >> 16) & 0xff) / 255.0 green:((c >> 8) & 0xff) / 255.0 blue:(c & 0xff) / 255.0 alpha:1.0]; }

- (NSString *)lineText:(int)line      /* line < 0: history, 0 ... rows - 1: the screen */
{
	NSMutableString *s = [NSMutableString string]; int cols = vt_cols(term);
	for (int x = 0; x < cols; x++) {
		const vt_cell *c = line >= 0 ? vt_cell_at(term, x, line) : vt_scrollback_cell(term, x, -line - 1);
		if (!c || c->wide == 2) continue; unichar u = c->ch > 0xffff ? '?' : (unichar)c->ch; [s appendFormat:@"%C", (unichar)(u ? u : ' ')];
	}
	return s;
}

- (void)drawRect:(NSRect)dirty
{
	NSColor *defFg = profile->text, *defBg = profile->background; BOOL hasAlpha = [defBg alphaComponent] < 0.999;
	if (hasAlpha) { CGContextRef cg = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort]; CGContextSaveGState(cg); CGContextClearRect(cg, NSRectToCGRect(dirty)); CGContextRestoreGState(cg); }
	[defBg set]; NSRectFillUsingOperation(dirty, hasAlpha ? NSCompositeSourceOver : NSCompositeCopy);
	int cols = vt_cols(term), rows = vt_rows(term), curx, cury, curvis; vt_cursor(term, &curx, &cury, &curvis);
	int hist = vt_alt_screen(term) ? 0 : vt_scrollback_lines(term); if (scrollOffset > hist) scrollOffset = hist;
	for (int y = 0; y < rows; y++) {
		CGFloat py = y * cellH;
		if (py + cellH < dirty.origin.y || py > dirty.origin.y + dirty.size.height) continue;
		int srcline = y - scrollOffset;                                  /* < 0: a history line */
		for (int x = 0; x < cols; x++) {
			const vt_cell *c = srcline >= 0 ? vt_cell_at(term, x, srcline) : vt_scrollback_cell(term, x, -srcline - 1);
			if (!c) continue;
			uint32_t fg = c->fg, bg = c->bg; NSColor *f = fg == VT_DEFAULT_COLOR ? defFg : rgbColor(fg), *b = bg == VT_DEFAULT_COLOR ? defBg : rgbColor(bg);
			if ((c->attr & VT_BOLD) && fg == VT_DEFAULT_COLOR) f = profile->boldText;
			BOOL sel = hasSel && [self cellSelectedX:x y:y];
			BOOL inv = (c->attr & VT_INVERSE) != 0;
			if (inv) { NSColor *tmp = f; f = (bg == VT_DEFAULT_COLOR) ? defBg : b; b = (fg == VT_DEFAULT_COLOR) ? defFg : tmp; if ([f alphaComponent] < 1) f = [NSColor blackColor]; }
			if (c->wide == 2) continue;
			CGFloat w = (c->wide == 1 ? 2 : 1) * cellW;
			if (sel) { [profile->selection set]; NSRectFill(NSMakeRect(x * cellW, py, w, cellH)); }
			else if (bg != VT_DEFAULT_COLOR || inv) { [b set]; NSRectFill(NSMakeRect(x * cellW, py, w, cellH)); }
			if (c->ch != ' ' && c->ch != 0 && !(c->attr & VT_HIDDEN) && !((c->attr & VT_BLINK) && !blinkOn)) {
				unichar buf[2]; int n = 1;
				if (c->ch > 0xffff) { uint32_t v = c->ch - 0x10000; buf[0] = (unichar)(0xd800 + (v >> 10)); buf[1] = (unichar)(0xdc00 + (v & 0x3ff)); n = 2; } else buf[0] = (unichar)c->ch;
				NSString *s = [NSString stringWithCharacters:buf length:n];
				NSMutableDictionary *at = [NSMutableDictionary dictionaryWithObjectsAndKeys:((c->attr & VT_BOLD) ? boldFont : font), NSFontAttributeName, f, NSForegroundColorAttributeName, nil];
				if (c->attr & VT_UNDERLINE) [at setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
				if (c->attr & VT_STRIKE) [at setObject:[NSNumber numberWithInt:1] forKey:NSStrikethroughStyleAttributeName];
				[s drawAtPoint:NSMakePoint(x * cellW, py) withAttributes:at];
			}
		}
		if ([findQuery length]) {                                          /* the find highlights */
			NSString *line = [self lineText:y - scrollOffset]; NSRange r = NSMakeRange(0, 0);
			while (YES) {
				r = [line rangeOfString:findQuery options:findCase ? 0 : NSCaseInsensitiveSearch range:NSMakeRange(NSMaxRange(r), [line length] - NSMaxRange(r))];
				if (r.location == NSNotFound) break;
				[[NSColor colorWithCalibratedRed:1 green:0.85 blue:0.1 alpha:0.45] set]; NSRectFillUsingOperation(NSMakeRect(r.location * cellW, py, r.length * cellW, cellH), NSCompositeSourceOver);
			}
		}
	}
	if (curvis && scrollOffset == 0 && !exited && (blinkOn || !active || !profile->blink)) {
		NSRect cr = NSMakeRect(curx * cellW, cury * cellH, cellW, cellH);
		NSColor *cc = [profile->cursor alphaComponent] < 1 || [profile->cursor isEqual:profile->background] ? [NSColor colorWithCalibratedWhite:0.85 alpha:0.7] : profile->cursor;
		[cc set];
		if (active) NSRectFillUsingOperation(cr, NSCompositeSourceOver); else { NSFrameRectWithWidth(NSInsetRect(cr, 0.5, 0.5), 1); }   /* an inactive window draws the cursor hollow */
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
	case NSPageUpFunctionKey: if (mods & NSShiftKeyMask) { [self scrollPageUp:nil]; return; } seq = "\033[5~"; break;
	case NSPageDownFunctionKey: if (mods & NSShiftKeyMask) { [self scrollPageDown:nil]; return; } seq = "\033[6~"; break;
	case NSDeleteFunctionKey: seq = "\033[3~"; break;
	case NSF1FunctionKey: seq = "\033OP"; break; case NSF2FunctionKey: seq = "\033OQ"; break; case NSF3FunctionKey: seq = "\033OR"; break; case NSF4FunctionKey: seq = "\033OS"; break;
	case NSF5FunctionKey: seq = "\033[15~"; break; case NSF6FunctionKey: seq = "\033[17~"; break; case NSF7FunctionKey: seq = "\033[18~"; break; case NSF8FunctionKey: seq = "\033[19~"; break;
	case NSF9FunctionKey: seq = "\033[20~"; break; case NSF10FunctionKey: seq = "\033[21~"; break; case NSF11FunctionKey: seq = "\033[23~"; break; case NSF12FunctionKey: seq = "\033[24~"; break;
	case 0x7f: seq = "\x7f"; break;
	case 0x19: seq = "\033[Z"; break;                                      /* back tab */
	}
	scrollOffset = 0; hasSel = NO;
	if (seq) { if (master >= 0) (void)write(master, seq, strlen(seq)); return; }
	NSString *s = ((mods & NSAlternateKeyMask) && optionAsMeta) ? [@"\033" stringByAppendingString:[e charactersIgnoringModifiers]] : chars;   /* option sends escape */
	[self writeString:s];
}

- (void)scrollWheel:(NSEvent *)e
{
	if (vt_mouse_mode(term) && allowMouse) { NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; [self reportMouse:([e deltaY] > 0 ? 64 : 65) x:(int)(p.x / cellW) y:(int)(p.y / cellH) release:NO]; return; }
	if (vt_alt_screen(term)) { const char *s = [e deltaY] > 0 ? "\033[A\033[A\033[A" : "\033[B\033[B\033[B"; if (master >= 0) (void)write(master, s, strlen(s)); return; }
	scrollOffset += (int)([e deltaY] * 3) ; if (scrollOffset < 0) scrollOffset = 0; if (scrollOffset > vt_scrollback_lines(term)) scrollOffset = vt_scrollback_lines(term);
	hasSel = NO; [self setNeedsDisplay:YES];
}

- (void)reportMouse:(int)button x:(int)x y:(int)y release:(BOOL)rel
{
	if (x < 0) x = 0; if (y < 0) y = 0; if (x >= vt_cols(term)) x = vt_cols(term) - 1; if (y >= vt_rows(term)) y = vt_rows(term) - 1;
	char b[48];
	if (vt_mouse_sgr(term)) snprintf(b, sizeof b, "\033[<%d;%d;%d%c", button, x + 1, y + 1, rel ? 'm' : 'M');
	else snprintf(b, sizeof b, "\033[M%c%c%c", (char)(32 + (rel ? 3 : button)), (char)(32 + x + 1), (char)(32 + y + 1));
	if (master >= 0) (void)write(master, b, strlen(b));
}

- (BOOL)isWordChar:(unichar)u { return [[NSCharacterSet alphanumericCharacterSet] characterIsMember:u] || u == '_' || u == '/' || u == '.' || u == '-' || u == '~' || u == ':' || u == '@' || u == '%' || u == '+' || u == '#'; }

- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; int x = (int)(p.x / cellW), y = (int)(p.y / cellH);
	if (vt_mouse_mode(term) && allowMouse && !([e modifierFlags] & NSShiftKeyMask)) { [self reportMouse:0 x:x y:y release:NO]; return; }
	clickCount = (int)[e clickCount];
	if ([e modifierFlags] & NSShiftKeyMask && hasSel) { selEndX = x; selEndY = y; [self setNeedsDisplay:YES]; return; }
	selStartX = selEndX = x; selStartY = selEndY = y; hasSel = NO;
	if (clickCount == 2) {                                                  /* a word */
		NSString *line = [self lineText:y - scrollOffset]; int a = x, b = x, n = (int)[line length];
		if (x < n && [self isWordChar:[line characterAtIndex:x]]) { while (a > 0 && [self isWordChar:[line characterAtIndex:a - 1]]) a--; while (b + 1 < n && [self isWordChar:[line characterAtIndex:b + 1]]) b++; }
		selStartX = a; selEndX = b; hasSel = YES;
	} else if (clickCount >= 3) { selStartX = 0; selEndX = vt_cols(term) - 1; hasSel = YES; }      /* a line */
	[self setNeedsDisplay:YES];
}
- (void)mouseDragged:(NSEvent *)e
{
	NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; int x = (int)(p.x / cellW), y = (int)(p.y / cellH);
	if (vt_mouse_mode(term) >= 2 && allowMouse && !([e modifierFlags] & NSShiftKeyMask)) { [self reportMouse:32 x:x y:y release:NO]; return; }
	selEndX = x; selEndY = y; hasSel = YES; [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)e
{
	if (vt_mouse_mode(term) && allowMouse && !([e modifierFlags] & NSShiftKeyMask)) { NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; [self reportMouse:0 x:(int)(p.x / cellW) y:(int)(p.y / cellH) release:YES]; }
}
- (void)rightMouseDown:(NSEvent *)e
{
	NSMenu *m = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	[m addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@""]; [m addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]]; [m addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@""]; [m addItemWithTitle:@"Clear to Start" action:@selector(clearToStart:) keyEquivalent:@""];
	for (NSMenuItem *i in [m itemArray]) [i setTarget:self];
	[NSMenu popUpContextMenu:m withEvent:e forView:self];
}

- (NSString *)selectedText
{
	if (!hasSel) return @"";
	int a = selStartY * 4096 + selStartX, b = selEndY * 4096 + selEndX; if (a > b) { int t = a; a = b; b = t; }
	NSMutableString *out = [NSMutableString string]; int lastY = -1;
	for (int y = a / 4096; y <= b / 4096 && y < vt_rows(term); y++) {
		NSString *full = [self lineText:y - scrollOffset]; NSMutableString *line = [NSMutableString string];
		for (int x = 0; x < (int)[full length]; x++) { int p = y * 4096 + x; if (p < a || p > b) continue; [line appendFormat:@"%C", [full characterAtIndex:x]]; }
		while ([line hasSuffix:@" "]) [line deleteCharactersInRange:NSMakeRange([line length] - 1, 1)];
		if (lastY >= 0) [out appendString:@"\n"]; [out appendString:line]; lastY = y;
	}
	return out;
}
- (NSString *)allText
{
	NSMutableString *out = [NSMutableString string]; int h = vt_scrollback_lines(term);
	for (int l = -h; l < vt_rows(term); l++) { NSMutableString *line = [[[self lineText:l] mutableCopy] autorelease]; while ([line hasSuffix:@" "]) [line deleteCharactersInRange:NSMakeRange([line length] - 1, 1)]; [out appendString:line]; [out appendString:@"\n"]; }
	return out;
}
- (BOOL)dumpScreenToFile:(NSString *)path
{
	NSMutableString *out = [NSMutableString string];
	for (int y = 0; y < vt_rows(term); y++) { NSMutableString *line = [[[self lineText:y] mutableCopy] autorelease]; while ([line hasSuffix:@" "]) [line deleteCharactersInRange:NSMakeRange([line length] - 1, 1)]; [out appendString:line]; [out appendString:@"\n"]; }
	return [out writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

- (void)copy:(id)sender { (void)sender; NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil]; [pb setString:[self selectedText] forType:NSStringPboardType]; }
- (void)paste:(id)sender
{
	(void)sender; NSString *s = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]; if (!s) return;
	if (vt_bracketed_paste(term)) { [self writeString:@"\033[200~"]; [self writeString:s]; [self writeString:@"\033[201~"]; } else [self writeString:s];
}
- (void)selectAll:(id)sender { (void)sender; selStartX = 0; selStartY = 0; selEndX = vt_cols(term) - 1; selEndY = vt_rows(term) - 1; hasSel = YES; [self setNeedsDisplay:YES]; }

/* Clear Screen (the screen and the scrollback, as the real menu item does), Clear Scrollback, Clear to Start (everything above the cursor line), Reset, Hard Reset */
- (void)clearScreen:(id)sender { (void)sender; vt_feed(term, "\033[H\033[2J", 7); vt_clear_scrollback(term); scrollOffset = 0; hasSel = NO; [self writeString:@"\014"]; }
- (void)clearScrollback:(id)sender { (void)sender; vt_clear_scrollback(term); scrollOffset = 0; [self setNeedsDisplay:YES]; }
- (void)clearToStart:(id)sender
{
	(void)sender; int cx, cy, cv; vt_cursor(term, &cx, &cy, &cv); vt_clear_scrollback(term);
	char b[64]; snprintf(b, sizeof b, "\033[1;1H\033[%dL", 1); (void)b;
	for (int y = 0; y < cy; y++) { char m[32]; snprintf(m, sizeof m, "\033[%d;1H\033[2K", y + 1); vt_feed(term, m, strlen(m)); }
	char back[32]; snprintf(back, sizeof back, "\033[%d;%dH", cy + 1, cx + 1); vt_feed(term, back, strlen(back)); scrollOffset = 0; [self setNeedsDisplay:YES];
}
- (void)resetTerminal:(id)sender { (void)sender; vt_feed(term, "\033c", 2); vt_set_ansi(term, profile->ansi); [self setNeedsDisplay:YES]; }
- (void)hardResetTerminal:(id)sender { [self resetTerminal:sender]; vt_clear_scrollback(term); scrollOffset = 0; }

- (void)biggerFont:(id)sender { (void)sender; fontSize += 1; if (fontSize > 96) fontSize = 96; [self rebuildFont]; [self relayoutAfterFontChange]; }
- (void)smallerFont:(id)sender { (void)sender; fontSize -= 1; if (fontSize < 6) fontSize = 6; [self rebuildFont]; [self relayoutAfterFontChange]; }
- (void)defaultFontSize:(id)sender { (void)sender; fontSize = profile->fontSize; [self rebuildFont]; [self relayoutAfterFontChange]; }
- (void)relayoutAfterFontChange { [self setNeedsDisplay:YES]; if ([delegate respondsToSelector:@selector(termViewFontChanged:)]) [delegate termViewFontChanged:self]; }

- (void)scrollToTop:(id)sender { (void)sender; scrollOffset = vt_scrollback_lines(term); hasSel = NO; [self setNeedsDisplay:YES]; }
- (void)scrollToBottom:(id)sender { (void)sender; scrollOffset = 0; [self setNeedsDisplay:YES]; }
- (void)scrollBy:(int)n { scrollOffset += n; if (scrollOffset < 0) scrollOffset = 0; if (scrollOffset > vt_scrollback_lines(term)) scrollOffset = vt_scrollback_lines(term); hasSel = NO; [self setNeedsDisplay:YES]; }
- (void)scrollPageUp:(id)sender { (void)sender; [self scrollBy:vt_rows(term) - 1]; }
- (void)scrollPageDown:(id)sender { (void)sender; [self scrollBy:-(vt_rows(term) - 1)]; }
- (void)scrollLineUp:(id)sender { (void)sender; [self scrollBy:1]; }
- (void)scrollLineDown:(id)sender { (void)sender; [self scrollBy:-1]; }

- (void)setFindHighlight:(NSString *)s { [findQuery release]; findQuery = [s copy]; [self setNeedsDisplay:YES]; }
- (BOOL)findText:(NSString *)s forward:(BOOL)fwd caseSensitive:(BOOL)cs
{
	if (![s length]) return NO;
	findCase = cs; int h = vt_scrollback_lines(term), rows = vt_rows(term), total = h + rows;
	int startLine = (hasSel ? selEndY : (fwd ? 0 : rows - 1)) - scrollOffset, startCol = hasSel ? (fwd ? selEndX + 1 : selStartX - 1) : 0;
	for (int i = 0; i <= total; i++) {
		int line = fwd ? startLine + i : startLine - i; if (line >= rows) line -= total; if (line < -h) line += total;
		NSString *t = [self lineText:line]; NSRange rg = NSMakeRange(0, [t length]);
		if (i == 0) { if (fwd) { if (startCol >= (int)[t length]) continue; rg = NSMakeRange(startCol, [t length] - startCol); } else { if (startCol < 0) continue; rg = NSMakeRange(0, startCol + 1); } }
		NSRange f = [t rangeOfString:s options:(cs ? 0 : NSCaseInsensitiveSearch) | (fwd ? 0 : NSBackwardsSearch) range:rg];
		if (f.location == NSNotFound) continue;
		if (line < 0 - 0 && line - 0 < 0) scrollOffset = -line + 0 > scrollOffset ? -line : scrollOffset; else if (line - scrollOffset < 0 || scrollOffset > 0) scrollOffset = scrollOffset > 0 && line >= 0 ? 0 : scrollOffset;
		if (line < 0) scrollOffset = -line; else scrollOffset = 0;
		int y = line + scrollOffset;
		selStartX = (int)f.location; selEndX = (int)(f.location + f.length - 1); selStartY = selEndY = y; hasSel = YES; [self setNeedsDisplay:YES]; return YES;
	}
	return NO;
}

@end

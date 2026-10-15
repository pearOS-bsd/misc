#import "ksa.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Apple's English strings (Localizable.loctable of KeyboardSetupAssistant) */
#define S_TITLE_INTRO     @"Keyboard Setup Assistant"
#define S_TITLE_IDENT     @"Identifying Your Keyboard"
#define S_TITLE_SELECT    @"Select the Keyboard Type"
#define S_INTRO           @"Your USB Keyboard device cannot be identified and will not be usable until it is identified.\n\nIf your keyboard is working properly and you have an additional USB input device connected to your computer that is not a keyboard, you may quit this application."
#define S_LEFT            @"Press the key immediately to the right of the Shift key on the left side of the keyboard."
#define S_RIGHT           @"Press the key immediately to the left of the Shift key on the right side of the keyboard."
#define S_SHIFT_SUB       @"Press the key only once and do not hold down the key for a long time. When the key is recognized, the next panel will appear."
#define S_CONFIRM         @"Your keyboard has been identified. If this isn‘t the correct type for your keyboard, select the type and click Done."
#define S_WARNING         @"The keys you pressed were not recognized. Click OK to select the keyboard type."
#define S_WARNING_TITLE   @"Your keyboard cannot be identified."
#define S_ANSI_T @"ANSI (U.S.)"
#define S_ANSI_H @"Standard 101-key or 102-key keyboard and some other keyboards"
#define S_ISO_T  @"ISO (International)"
#define S_ISO_H  @"ISO/IEC 9995 standard keyboard"
#define S_JIS_T  @"JIS (Japan)"
#define S_JIS_H  @"Japanese standard keyboard with input method keys"
#define S_MACISO_H @"ISO/Macintosh keyboard"

static const char *typeName(int t) { return t == KSATypeJIS ? "JIS" : t == KSATypeISO ? "ISO" : t == KSATypeISOMac ? "ISO Mac" : t == KSATypeANSI ? "ANSI" : "Unknown"; }

/* the real app stores the choice with SystemAdministration; here it goes to stdout and, when KSA_OUTPUT names a file, into it (never into the system) */
static void writeKeyboardType(int t)
{
	printf("KeyboardType=%s\n", typeName(t)); fflush(stdout);
	const char *f = getenv("KSA_OUTPUT");
	if (f) { FILE *o = fopen(f, "w"); if (o) { fprintf(o, "%s\n", typeName(t)); fclose(o); } }
}

@class KSAController;

@interface KSAWindow : NSWindow { KSAController *controller; }
- (void) setController: (KSAController *)c;
@end

@interface KSAController : NSObject {
	KSAWindow *window; NSView *pane; int current; int detected; int chosen;
	NSButton *first, *second; NSMutableArray *radios;
}
- (id) initWithWindow: (KSAWindow *)w;
- (void) showPane: (int)p;
- (void) goToNextPane;
- (void) goToPreviousPane;
- (void) finalizeAndQuit;
- (void) handleKeyCode: (unsigned short)code modifiers: (NSUInteger)flags;
- (void) runScriptItem: (NSString *)item;
@end

@implementation KSAWindow
- (BOOL) canBecomeKeyWindow { return YES; }
- (BOOL) canBecomeMainWindow { return YES; }
- (void) setController: (KSAController *)c { controller = c; }
- (void) keyDown: (NSEvent *)e { [controller handleKeyCode: [e keyCode] modifiers: [e modifierFlags]]; }
@end

static NSTextField *label(NSString *s, NSRect f, NSFont *font, NSColor *color, NSTextAlignment al)
{
	NSTextField *t = [[[NSTextField alloc] initWithFrame: f] autorelease];
	[t setStringValue: s]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setBordered: NO]; [t setDrawsBackground: NO];
	[t setFont: font]; [t setTextColor: color]; [t setAlignment: al];
	return t;
}

static NSColor *secondary(void) { return [[NSColor controlTextColor] colorWithAlphaComponent: 0.65]; }

/* the keyboard glyph on the top of the introduction and selection panes (Apple draws an SF Symbol: resources/keyboard.png when a copy is available, else this outline) */
@interface KSAGlyph : NSView
@end
@implementation KSAGlyph
- (void) drawRect: (NSRect)r
{
	NSImage *img = nil; NSString *p = [[NSBundle mainBundle] pathForResource: @"keyboard" ofType: @"png"];
	if (!p) p = @"resources/keyboard.png";
	if ([[NSFileManager defaultManager] fileExistsAtPath: p]) img = [[[NSImage alloc] initWithContentsOfFile: p] autorelease];
	if (img) { [img drawInRect: [self bounds] fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0]; return; }
	NSRect b = NSInsetRect([self bounds], 4, 14);
	[[NSColor colorWithCalibratedRed: 0.0 green: 0.48 blue: 1.0 alpha: 1.0] set];
	NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6]; [o setLineWidth: 3]; [o stroke];
	for (int row = 0; row < 3; row++) for (int k = 0; k < 6; k++) NSRectFill(NSMakeRect(b.origin.x + 8 + k * 8.5, b.origin.y + 8 + row * 9, 5.5, 5));
}
@end

@implementation KSAController

- (id) initWithWindow: (KSAWindow *)w
{
	self = [super init];
	window = w; current = -1; detected = KSATypeUnknown; chosen = KSATypeUnknown;
	[w setController: self];
	return self;
}

- (NSButton *) buttonWithTitle: (NSString *)t frame: (NSRect)f action: (SEL)a
{
	NSButton *b = [[[NSButton alloc] initWithFrame: f] autorelease];
	[b setTitle: t]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: self]; [b setAction: a];
	return b;
}

- (void) radioChosen: (id)sender
{
	chosen = (int)[sender tag];
	for (NSButton *r in radios) [r setState: r == sender ? NSOnState : NSOffState];
	[first setEnabled: YES];
	fprintf(stderr, "User selected keyboard: %s\n", typeName(chosen));
}

- (void) showPane: (int)p
{
	current = p;
	if (pane) [pane removeFromSuperview];
	NSRect cb = [[window contentView] bounds];
	pane = [[[NSView alloc] initWithFrame: cb] autorelease];
	CGFloat W = cb.size.width, H = cb.size.height;
	NSColor *tc = [NSColor controlTextColor];
	NSString *title = p == 0 ? S_TITLE_INTRO : p == 3 ? S_TITLE_SELECT : S_TITLE_IDENT;
	NSString *body = p == 0 ? S_INTRO : p == 1 ? [NSString stringWithFormat: @"%@\n\n%@", S_LEFT, S_SHIFT_SUB] : p == 2 ? [NSString stringWithFormat: @"%@\n\n%@", S_RIGHT, S_SHIFT_SUB] : (detected == KSATypeUnknown ? S_WARNING : S_CONFIRM);
	if (p == 0 || p == 3) { KSAGlyph *g = [[[KSAGlyph alloc] initWithFrame: NSMakeRect((W - 64) / 2, H - 120, 64, 64)] autorelease]; [pane addSubview: g]; }
	[pane addSubview: label(title, NSMakeRect(60, H - 180, W - 120, 36), [NSFont boldSystemFontOfSize: 26], tc, NSCenterTextAlignment)];
	[pane addSubview: label(body, NSMakeRect(140, p == 3 ? H - 270 : H - 330, W - 280, p == 3 ? 70 : 140), [NSFont systemFontOfSize: 15], tc, NSCenterTextAlignment)];
	[first release]; [second release]; first = second = nil; [radios release]; radios = nil;
	first = [[self buttonWithTitle: p == 3 ? @"Done" : @"Continue" frame: NSMakeRect(W - 20 - 100, 20, 100, 32) action: p == 3 ? @selector(finalizeAndQuit) : @selector(goToNextPane)] retain];
	second = [[self buttonWithTitle: p == 0 ? @"Quit" : @"Back" frame: NSMakeRect(W - 20 - 100 - 12 - 100, 20, 100, 32) action: p == 0 ? @selector(quit) : @selector(goToPreviousPane)] retain];
	[first setKeyEquivalent: @"\r"];
	if (p == 1 || p == 2) [first setEnabled: NO];                      /* waiting for the key press */
	[pane addSubview: first]; [pane addSubview: second];
	if (p == 3) {
		radios = [[NSMutableArray alloc] init];
		struct { int t; NSString *ti, *hi; } opts[3] = { { KSATypeANSI, S_ANSI_T, S_ANSI_H }, { KSATypeISO, S_ISO_T, S_ISO_H }, { KSATypeJIS, S_JIS_T, S_JIS_H } };
		if (detected == KSATypeISOMac) opts[1].hi = S_MACISO_H;
		CGFloat y = H - 330;
		for (int i = 0; i < 3; i++) {
			NSButton *r = [[[NSButton alloc] initWithFrame: NSMakeRect(220, y, W - 440, 20)] autorelease];
			[r setButtonType: NSRadioButton]; [r setTitle: opts[i].ti]; [r setTag: opts[i].t]; [r setTarget: self]; [r setAction: @selector(radioChosen:)];
			[r setState: (detected != KSATypeUnknown && (opts[i].t == detected || (detected == KSATypeISOMac && opts[i].t == KSATypeISO))) ? NSOnState : NSOffState];
			[pane addSubview: r]; [radios addObject: r];
			[pane addSubview: label(opts[i].hi, NSMakeRect(242, y - 18, W - 480, 16), [NSFont systemFontOfSize: 11], secondary(), NSLeftTextAlignment)];
			y -= 54;
		}
		chosen = detected;
		[first setEnabled: detected != KSATypeUnknown];
	}
	[[window contentView] addSubview: pane];
	[window display];
}

- (void) quit { fprintf(stderr, "Quit: keyboard left at its default\n"); [NSApp terminate: nil]; }

- (void) goToNextPane
{
	fprintf(stderr, "Next pane called from pane: %d\n", current);
	if (current == 2 || current == 1) { [self showPane: 3]; return; }
	[self showPane: current + 1];
}

- (void) goToPreviousPane
{
	fprintf(stderr, "Previous pane called from pane: %d\n", current);
	if (current <= 0) return;
	[self showPane: current == 3 ? 1 : current - 1];
}

- (void) finalizeAndQuit
{
	fprintf(stderr, "User confirmed selection of keyboard: %s\n", typeName(chosen));
	writeKeyboardType(chosen);
	[NSApp terminate: nil];
}

/* the key handler of the two Shift panes (FUN_100006088 of the original) */
- (void) handleKeyCode: (unsigned short)code modifiers: (NSUInteger)flags
{
	if (current != 1 && current != 2) return;
	if (code == 0x0c && (flags & NSCommandKeyMask)) return;               /* Cmd+Q */
	static const unsigned short leftKeys[3] = { 0x0a, 0x32, 0x06 };
	static const unsigned short rightKeys[3] = { 0x2c, 0x5e, 0x0a };
	const unsigned short *keys = current == 1 ? leftKeys : rightKeys; int ok = 0;
	for (int i = 0; i < 3; i++) if (keys[i] == code) ok = 1;
	if (!ok) { fprintf(stderr, "Key ID: %d is not one of the expected keys\n", code); NSBeep(); return; }
	fprintf(stderr, "Key ID: %d pressed on correct keyboard.\n", code);
	int t = code == 0x0a ? KSATypeISO : code == 0x2c ? KSATypeANSI : code == 0x32 ? KSATypeISOMac : code == 0x5e ? KSATypeJIS : KSATypeUnknown;
	detected = t;
	if (current == 1 && t != KSATypeUnknown) { fprintf(stderr, "Automatically detected keyboard: %s\n", typeName(detected)); [self showPane: 3]; return; }
	if (current == 1) { [self goToNextPane]; return; }                   /* Z: ANSI or JIS, the right pane tells */
	fprintf(stderr, "Automatically detected keyboard: %s\n", typeName(detected));
	[self showPane: 3];
}

- (void) runScriptItem: (NSString *)item
{
	if ([item isEqualToString: @"next"]) [self goToNextPane];
	else if ([item isEqualToString: @"back"]) [self goToPreviousPane];
	else if ([item isEqualToString: @"done"]) [self finalizeAndQuit];
	else if ([item hasPrefix: @"key:"]) [self handleKeyCode: (unsigned short)[[item substringFromIndex: 4] intValue] modifiers: 0];
	else if ([item hasPrefix: @"pane:"]) [self showPane: [[item substringFromIndex: 5] intValue]];
	else if ([item hasPrefix: @"select:"]) { for (NSButton *r in radios) if ([r tag] == [[item substringFromIndex: 7] intValue]) [self radioChosen: r]; }
}
@end

@interface KSADelegate : NSObject { KSAWindow *window; KSAController *controller; NSArray *script; int step; }
@end
@implementation KSADelegate
- (void) applicationDidFinishLaunching: (NSNotification *)n
{
	NSRect r = NSMakeRect(0, 0, 800, 600);
	window = [[KSAWindow alloc] initWithContentRect: r styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[window setTitle: S_TITLE_INTRO];
	controller = [[KSAController alloc] initWithWindow: window];
	const char *sp = getenv("KSA_PANE");
	[controller showPane: sp ? atoi(sp) : 0];
	[window center]; [window makeKeyAndOrderFront: nil];
	const char *sc = getenv("KSA_SCRIPT");
	if (sc) { script = [[[NSString stringWithUTF8String: sc] componentsSeparatedByString: @","] retain]; [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(tick:) userInfo: nil repeats: YES]; }
	const char *ex = getenv("KSA_EXIT_AFTER");
	if (ex) [NSTimer scheduledTimerWithTimeInterval: atof(ex) target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
}
- (void) tick: (NSTimer *)t { if (step < (int)[script count]) [controller runScriptItem: [script objectAtIndex: step++]]; }
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)a { return YES; }
@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	if ([NSApp respondsToSelector: @selector(setActivationPolicy:)]) [NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
	[NSApp setDelegate: [[KSADelegate alloc] init]];
	[NSApp activateIgnoringOtherApps: YES];
	[NSApp run];
	[pool release];
	return 0;
}

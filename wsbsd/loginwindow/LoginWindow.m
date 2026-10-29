/* loginwindow: the login window, before the first unlock of a session (the accounts of the machine, choose one, enter its password) and after it (the screen is locked: the account that is signed in, its password
 * unlocks). It prints the name of the account on its standard output and exits 0 when the password is right. Layout: the wallpaper under a blur, the account's picture (96 pt) with its name below and the
 * password field under that; with several accounts the pictures of all of them stand in a row. Font sizes measured on the Mac from LoginUIKit (docs/loginwindow/LoginUIKit.view-metrics.txt): time 0.14 and date 0.028 of the screen height,
 * name 15, hint 12.  Usage: loginwindow [--lock account]. Standard AppKit controls only (NSImageView, NSTextField, NSSecureTextField, NSButton,
 * NSVisualEffectView). */
#import <AppKit/AppKit.h>
#include <pwd.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>

extern char *crypt(const char *, const char *);
@interface NSObject (LWSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end

static BOOL Authenticate(NSString *user, NSString *password)
{
	struct passwd *p = getpwnam([user UTF8String]); if (!p) return NO; const char *h = p->pw_passwd; if (!h || !*h) return YES;       /* an account without a password */
	if (h[0] == '*' || h[0] == '!') return NO; char *c = crypt([password UTF8String], h); return c && strcmp(c, h) == 0;
}
/* the accounts that are signed in (a session each, listed by the session script): they get the badge of the Mac's login window (checkmark.circle.fill) */
static BOOL SignedIn(NSNumber *uid)
{
	NSString *t = [NSString stringWithContentsOfFile: @"/var/run/wsbsd/sessions" encoding: NSUTF8StringEncoding error: NULL]; for (NSString *l in [t componentsSeparatedByString: @"\n"]) if ([l length] && [l integerValue] == [uid integerValue]) return YES; return NO;
}
static NSArray *Accounts(void)
{
	NSMutableArray *r = [NSMutableArray array]; setpwent(); struct passwd *p;
	while ((p = getpwent())) { if (p->pw_uid < 500 || p->pw_uid >= 60000) continue; if (!p->pw_shell || strstr(p->pw_shell, "nologin") || strstr(p->pw_shell, "false")) continue; NSString *full = p->pw_gecos && *p->pw_gecos ? @(p->pw_gecos) : @(p->pw_name); NSRange c = [full rangeOfString: @","]; if (c.location != NSNotFound) full = [full substringToIndex: c.location]; [r addObject: @{ @"user": @(p->pw_name), @"name": full, @"uid": @(p->pw_uid) }]; }
	endpwent(); return r;
}
/* ---- the design of pearOS (pearOS-archlinux/pkgbuilds, kscreenlocker/pearOS-dark: Main.qml, components/Clock.qml, screenshot.png), in 1080 p units scaled to the screen ----
 * the wallpaper full screen; the clock: the date ("Friday, July 11", 27 px) over the time ("22:32", 133 px, bold), white at 40 %, the bottom of the time 300 px from the top; the account at the bottom centre: the avatar
 * (80 px, a white ring round a blue disc with a white person), the name (bold 15 px) 24 px under it, a pill 250 x 32 (white 20 %, corner 16) with the password as dots, the hint "Enter Password" (11 px bold) under it;
 * at the top right three small icons (display, restart, power; 22 px at x 1790, 1861, 1890 of 1920, y 25). */
@interface LWFace : NSView { @public BOOL focused; } @end
@implementation LWFace
- (void)drawRect:(NSRect)d
{
	NSRect r = [self bounds]; if (focused) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.30] setFill]; [[NSBezierPath bezierPathWithOvalInRect: r] fill]; r = NSInsetRect(r, r.size.width / 16, r.size.width / 16); }       /* the account the arrow keys are on */
	[[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithOvalInRect: r] fill];
	NSRect in = NSInsetRect(r, r.size.width / 14, r.size.width / 14); NSBezierPath *disc = [NSBezierPath bezierPathWithOvalInRect: in]; [[NSColor colorWithCalibratedRed: 0.42 green: 0.65 blue: 0.90 alpha: 1] setFill]; [disc fill];
	[NSGraphicsContext saveGraphicsState]; [disc addClip]; [[NSColor whiteColor] setFill]; CGFloat w = in.size.width;
	[[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMidX(in) - w * 0.17, NSMidY(in) + w * 0.02, w * 0.34, w * 0.34)] fill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMidX(in) - w * 0.30, NSMinY(in) - w * 0.28, w * 0.60, w * 0.60)] fill]; [NSGraphicsContext restoreGraphicsState];
}
@end
/* a text drawn directly in a colour with alpha (the label cells of the theme draw their text opaque) */
@interface LWText : NSView { @public NSString *text; NSFont *font; NSColor *color; } @end
@implementation LWText
- (void)drawRect:(NSRect)d { NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSCenterTextAlignment]; NSDictionary *at = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: ps }; NSSize z = [text sizeWithAttributes: at]; [text drawInRect: NSMakeRect(0, ([self bounds].size.height - z.height) / 2, [self bounds].size.width, z.height) withAttributes: at]; }
@end
/* the password field of the design: white dots in the pill, no field chrome. It takes the keys itself (the theme draws every text field with a bezel and a dark box) */
@interface LWSecure : NSView { @public NSMutableString *value; id target; SEL action; } - (NSString *)stringValue; - (void)setStringValue:(NSString *)s; @end
@implementation LWSecure
- (BOOL)acceptsFirstResponder { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSString *)stringValue { return value ?: @""; } - (void)setStringValue:(NSString *)s { value = [s mutableCopy]; [self setNeedsDisplay: YES]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *c = [e characters]; if (![c length]) return; unichar k = [c characterAtIndex: 0]; if (!value) value = [NSMutableString string];
	if (k == 27) { id w = [self window]; if ([w respondsToSelector: @selector(keyDown:)]) { [w keyDown: e]; return; } }
	if (k == '\r' || k == '\n') { [target performSelector: action withObject: self]; return; }
	if (k == 0x7f || k == 8) { if ([value length]) [value deleteCharactersInRange: NSMakeRange([value length] - 1, 1)]; }
	else if (k >= 32 && !(k >= 0xF700 && k <= 0xF8FF)) [value appendString: c];
	[self setNeedsDisplay: YES];
}
- (void)drawRect:(NSRect)d
{
	NSRect b = [self bounds]; CGFloat dot = b.size.height * 0.34, gap = dot * 0.55, n = (CGFloat)[value length], w = n * dot + (n > 0 ? (n - 1) * gap : 0), x = NSMidX(b) - w / 2; if (w > b.size.width) x = NSMaxX(b) - w;
	[[NSColor whiteColor] setFill]; for (NSUInteger i = 0; i < [value length]; i++) { [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x + i * (dot + gap), NSMidY(b) - dot / 2, dot, dot)] fill]; }
}
@end
/* the pill of the password field */
@interface LWPill : NSView @end
@implementation LWPill
- (void)drawRect:(NSRect)d { NSRect b = [self bounds]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.20] setFill]; [[NSBezierPath bezierPathWithRoundedRect: b xRadius: b.size.height / 2 yRadius: b.size.height / 2] fill]; }
@end
/* a transparent view over a face / an icon: a press on it acts */
@interface LWClick : NSView { @public id target; SEL action; NSInteger index; NSString *symbol; } @end
@implementation LWClick
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)mouseDown:(NSEvent *)e { [target performSelector: action withObject: self]; }
- (void)drawRect:(NSRect)d { if (symbol) [NSClassFromString(@"WsdFinderSupport") drawSymbol: symbol inRect: [self bounds] size: [self bounds].size.width * 0.78 weight: 5 color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.92]]; }
@end

@interface NSObject (LWNav) - (BOOL)keyNav:(NSEvent *)e; @end
/* a borderless window cannot become key by default: the password field would get no keys */
@interface LWWindow : NSWindow { @public id nav; } @end
@implementation LWWindow - (BOOL)canBecomeKeyWindow { return YES; } - (BOOL)canBecomeMainWindow { return YES; }
- (void)keyDown:(NSEvent *)e { if (!(nav && [nav keyNav: e])) [super keyDown: e]; }       /* the arrow keys choose an account, Return takes it, Escape goes back to the accounts */
@end

@interface LWController : NSObject { NSWindow *win, *back, *clockWin; NSArray *accounts; NSInteger chosen, focus; LWSecure *pw; LWPill *pill; LWText *dateL, *timeL; NSTextField *msg; NSMutableArray *faces, *names; BOOL lock; CGFloat sc; NSRect sf; }
- (instancetype)initLock:(NSString *)user;
- (void)show;
@end
@implementation LWController
- (instancetype)initLock:(NSString *)user
{
	if (!(self = [super init])) return nil; lock = user != nil; accounts = Accounts();
	if (lock) { NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *d in accounts) if ([d[@"user"] isEqual: user]) [a addObject: d]; if (![a count]) [a addObject: @{ @"user": user, @"name": user }]; accounts = a; }
	return self;
}
/* a rectangle given in the design's units (1920 x 1080, y from the top, the centre of the item) */
- (NSRect)rectCX:(CGFloat)cx cy:(CGFloat)cy w:(CGFloat)w h:(CGFloat)h { return NSMakeRect(cx * sc * 1.0 - w * sc / 2 + (sf.size.width - 1920 * sc) / 2, sf.size.height - cy * sc - h * sc / 2, w * sc, h * sc); }
- (void)show
{
	sf = [[NSScreen mainScreen] frame]; sc = MAX(0.5, sf.size.height / 1080.0);
	win = [[LWWindow alloc] initWithContentRect: sf styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [win setLevel: 2000]; [win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]];
	((LWWindow *)win)->nav = self; NSView *cv = [win contentView];
	/* the wallpaper is a window of its own under the one with the controls */
	NSImage *wall = [[NSImage alloc] initWithContentsOfFile: @"/System/Library/Desktop Pictures/dark-mode.jpg"];
	if (wall) { [wall setSize: sf.size]; back = [[NSWindow alloc] initWithContentRect: sf styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [back setLevel: 1999]; [back setOpaque: YES]; NSImageView *iv = [[NSImageView alloc] initWithFrame: NSMakeRect(0, 0, sf.size.width, sf.size.height)]; [iv setImage: wall]; [iv setImageScaling: NSImageScaleAxesIndependently]; [back setContentView: iv]; [back orderFront: nil]; }
	else { [win setOpaque: YES]; [win setBackgroundColor: [NSColor blackColor]]; }
	clockWin = [[NSWindow alloc] initWithContentRect: sf styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [clockWin setLevel: 2000]; [clockWin setOpaque: NO]; [clockWin setBackgroundColor: [NSColor clearColor]]; [clockWin setIgnoresMouseEvents: YES]; NSView *clockCv = [clockWin contentView];       /* the clock is translucent as a whole: a window of its own with an alpha (the glyphs ignore the alpha of their colour) */
	NSColor *clockColor = [NSColor whiteColor];
	dateL = [[LWText alloc] initWithFrame: NSZeroRect]; dateL->font = [NSFont systemFontOfSize: sf.size.height * 0.028]; dateL->color = clockColor; [dateL setFrame: NSMakeRect(0, sf.size.height - 300 * sc + 166 * sc * 0.86, sf.size.width, 36 * sc)]; [clockCv addSubview: dateL];
	timeL = [[LWText alloc] initWithFrame: NSZeroRect]; timeL->font = [NSFont boldSystemFontOfSize: sf.size.height * 0.14]; timeL->color = clockColor; [timeL setFrame: NSMakeRect(0, sf.size.height - 300 * sc, sf.size.width, 166 * sc)]; [clockCv addSubview: timeL];
	[clockWin setAlphaValue: 0.42]; [clockWin orderFront: nil]; [self tick: nil]; [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	faces = [NSMutableArray array]; names = [NSMutableArray array]; NSUInteger n = [accounts count]; CGFloat pitch = 150;
	for (NSUInteger i = 0; i < n; i++) {
		CGFloat cx = 960 + ((CGFloat)i - (n - 1) / 2.0) * pitch;
		LWFace *av = [[LWFace alloc] initWithFrame: [self rectCX: cx cy: 889 w: 80 h: 80]]; [cv addSubview: av]; [faces addObject: av];
		if (SignedIn(accounts[i][@"uid"])) { LWClick *bd = [[LWClick alloc] initWithFrame: NSMakeRect(80 * sc - 22 * sc, 0, 22 * sc, 22 * sc)]; bd->symbol = @"checkmark.circle.fill"; [av addSubview: bd]; }
		LWClick *b = [[LWClick alloc] initWithFrame: [av frame]]; b->target = self; b->action = @selector(choose:); b->index = (NSInteger)i; [cv addSubview: b];
		NSTextField *l = [NSTextField labelWithString: accounts[i][@"name"]]; [l setFont: [NSFont boldSystemFontOfSize: 15 * sc]]; [l setTextColor: [NSColor whiteColor]]; [l setAlignment: NSCenterTextAlignment]; [l setFrame: [self rectCX: cx cy: 960 w: 140 h: 22]]; [cv addSubview: l]; [names addObject: l];
	}
	pill = [[LWPill alloc] initWithFrame: [self rectCX: 960 cy: 998 w: 250 h: 32]]; [cv addSubview: pill];
	pw = [[LWSecure alloc] initWithFrame: NSMakeRect(14 * sc, 5 * sc, 222 * sc, 22 * sc)]; pw->target = self; pw->action = @selector(submit:); [pill addSubview: pw];
	msg = [NSTextField labelWithString: @"Enter Password"]; [msg setTextColor: [NSColor colorWithCalibratedWhite: 1 alpha: 0.9]]; [msg setAlignment: NSCenterTextAlignment]; [msg setFont: [NSFont boldSystemFontOfSize: 12 * sc]]; [msg setFrame: [self rectCX: 960 cy: 1034 w: 320 h: 18]]; [cv addSubview: msg];
	/* the icons at the top right: display (nothing to switch here), restart, power */
	NSArray *icons = lock ? @[ @[ @"person.crop.circle", @1740 ], @[ @"display", @1790 ], @[ @"power", @1888 ] ] : @[ @[ @"display", @1790 ], @[ @"arrow.clockwise", @1850 ], @[ @"power", @1890 ] ];
	for (NSArray *ic in icons) { NSRect ir = [self rectCX: 960 cy: 28 w: 24 h: 24]; ir.origin.x = sf.size.width - (1920 - [ic[1] doubleValue]) * sc - 12 * sc;       /* anchored to the right edge: the design is 16:9 */
		LWClick *b = [[LWClick alloc] initWithFrame: ir]; b->symbol = ic[0]; b->target = self; b->action = [ic[0] isEqual: @"power"] ? @selector(shutdown:) : [ic[0] isEqual: @"arrow.clockwise"] ? @selector(restart:) : [ic[0] isEqual: @"person.crop.circle"] ? @selector(switchUser:) : @selector(noop:); [cv addSubview: b]; }
	chosen = n == 1 ? 0 : -1; [self refresh]; [win makeKeyAndOrderFront: nil]; [win orderFrontRegardless]; [win display]; [NSApp activateIgnoringOtherApps: YES]; if (chosen >= 0) [win makeFirstResponder: pw];
}
- (BOOL)keyNav:(NSEvent *)e
{
	NSString *c = [e characters]; if (![c length]) return NO; unichar k = [c characterAtIndex: 0]; NSInteger n = (NSInteger)[accounts count];
	if (chosen < 0) {
		if (k == 0xF702 && focus > 0) focus--; else if (k == 0xF703 && focus < n - 1) focus++; else if (k == '\r' || k == '\n') { chosen = focus; [pw setStringValue: @""]; [self setMessage: @"Enter Password"]; [self refresh]; [win makeFirstResponder: pw]; return YES; } else return NO;
		[self refresh]; return YES;
	}
	if (k == 27 && n > 1) { focus = chosen; chosen = -1; [pw setStringValue: @""]; [self refresh]; [win makeFirstResponder: nil]; return YES; }       /* back to the accounts */
	return NO;
}
- (void)setMessage:(NSString *)t       /* the label is made again: the window has no background, so a new text drew over the old one */
{
	NSView *sv = [msg superview]; NSRect f = [msg frame]; NSColor *c = [msg textColor]; NSFont *fn = [msg font]; BOOL h = [msg isHidden]; [msg removeFromSuperview];
	msg = [NSTextField labelWithString: t]; [msg setTextColor: c]; [msg setAlignment: NSCenterTextAlignment]; [msg setFont: fn]; [msg setFrame: f]; [msg setHidden: h]; [sv addSubview: msg]; [sv setNeedsDisplayInRect: f];
}
- (void)shake       /* a wrong password: the field shakes sideways, three swings dying away in half a second, as the Mac's login window does */
{
	static NSTimer *t; if (t) return; NSRect home = [pill frame]; NSDate *t0 = [NSDate date]; __weak LWPill *p = pill;
	t = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 repeats: YES block: ^(NSTimer *tm) { double e = -[t0 timeIntervalSinceNow] / (getenv("LW_SLOW") ? 4.0 : 0.5); if (e >= 1) { [p setFrame: home]; [[p superview] setNeedsDisplay: YES]; [tm invalidate]; t = nil; return; } NSRect f = home; f.origin.x += 14.0 * sin(e * 2 * M_PI * 3) * (1 - e); if (getenv("LW_DEBUG")) NSLog(@"shake e=%.2f x=%.1f", e, f.origin.x); [p setFrame: f]; [[p superview] setNeedsDisplay: YES]; }];
}
- (void)noop:(id)s {}
- (void)switchUser:(id)s { exit(3); }       /* Switch User: the session keeps running, the console goes to the login window (the session script sees the exit status 3) */

- (void)tick:(NSTimer *)t { NSDateFormatter *f = [[NSDateFormatter alloc] init]; [f setLocale: [[NSLocale alloc] initWithLocaleIdentifier: @"en_US"]]; [f setDateFormat: @"EEEE, MMMM d"]; dateL->text = [f stringFromDate: [NSDate date]]; [dateL setNeedsDisplay: YES]; [f setDateFormat: @"HH:mm"]; timeL->text = [f stringFromDate: [NSDate date]]; [timeL setNeedsDisplay: YES]; }
- (void)refresh
{
	BOOL one = chosen >= 0; [pill setHidden: !one]; [msg setHidden: !one];
	for (NSUInteger k = 0; k < [faces count]; k++) { ((LWFace *)faces[k])->focused = !one && (NSInteger)k == focus; [faces[k] setNeedsDisplay: YES]; }
	for (NSUInteger k = 0; k < [faces count]; k++) { BOOL mine = (NSInteger)k == chosen; [(LWFace *)faces[k] setHidden: one && !mine]; [(NSTextField *)names[k] setHidden: one && !mine];
		NSUInteger n = [accounts count]; CGFloat cx = one && mine ? 960 : 960 + ((CGFloat)k - (n - 1) / 2.0) * 150;       /* the chosen account goes to the middle, the row comes back when Escape returns to the accounts */
		if (!one || mine) { [(LWFace *)faces[k] setFrame: [self rectCX: cx cy: 889 w: 80 h: 80]]; [(NSTextField *)names[k] setFrame: [self rectCX: cx cy: 960 w: 140 h: 22]]; } }
}
- (void)choose:(LWClick *)b { chosen = b->index; [pw setStringValue: @""]; [self setMessage: @"Enter Password"]; [self refresh]; [win makeFirstResponder: pw]; }
- (void)submit:(id)s
{
	if (chosen < 0) return; NSString *u = accounts[chosen][@"user"];
	if (Authenticate(u, [pw stringValue])) { printf("%s\n", [u UTF8String]); fflush(stdout); exit(0); }
	[self setMessage: @"Incorrect password"]; [pw setStringValue: @""]; [win makeFirstResponder: pw]; [self shake];
}
- (void)restart:(id)s { system("/sbin/shutdown -r now"); }
- (void)shutdown:(id)s { system("/sbin/shutdown -p now"); }
@end

int main(int argc, char **argv)
{
	@autoreleasepool {
		NSString *lockUser = nil; for (int i = 1; i < argc - 1; i++) if (!strcmp(argv[i], "--lock")) lockUser = @(argv[i + 1]);
		[NSApplication sharedApplication]; LWController *c = [[LWController alloc] initLock: lockUser]; [c show]; [NSApp run];
	}
	return 1;
}

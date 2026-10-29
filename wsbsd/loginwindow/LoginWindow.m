/* loginwindow: the login window, before the first unlock of a session (the accounts of the machine, choose one, enter its password) and after it (the screen is locked: the account that is signed in, its password
 * unlocks). It prints the name of the account on its standard output and exits 0 when the password is right. Layout: the wallpaper under a blur, the account's picture (96 pt) with its name below and the
 * password field under that; with several accounts the pictures of all of them stand in a row. Not measured on a Mac (the real login window cannot be captured without signing out): the sizes are those of
 * the Mac's login window as far as the author remembers them, to be replaced by measurements.  Usage: loginwindow [--lock account]. Standard AppKit controls only (NSImageView, NSTextField, NSSecureTextField, NSButton,
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
static NSArray *Accounts(void)
{
	NSMutableArray *r = [NSMutableArray array]; setpwent(); struct passwd *p;
	while ((p = getpwent())) { if (p->pw_uid < 500 || p->pw_uid >= 60000) continue; if (!p->pw_shell || strstr(p->pw_shell, "nologin") || strstr(p->pw_shell, "false")) continue; NSString *full = p->pw_gecos && *p->pw_gecos ? @(p->pw_gecos) : @(p->pw_name); NSRange c = [full rangeOfString: @","]; if (c.location != NSNotFound) full = [full substringToIndex: c.location]; [r addObject: @{ @"user": @(p->pw_name), @"name": full }]; }
	endpwent(); return r;
}
/* the default picture of an account: a grey disc with head and shoulders */
@interface LWFace : NSView @end
@implementation LWFace
- (void)drawRect:(NSRect)d
{
	NSRect r = [self bounds]; NSBezierPath *disc = [NSBezierPath bezierPathWithOvalInRect: r]; [[NSColor colorWithCalibratedWhite: 0.55 alpha: 1] setFill]; [disc fill];
	[NSGraphicsContext saveGraphicsState]; [disc addClip]; [[NSColor colorWithCalibratedWhite: 0.88 alpha: 1] setFill];
	[[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(33, 50, 30, 30)] fill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(16, -26, 64, 64)] fill]; [NSGraphicsContext restoreGraphicsState];
}
@end
/* a transparent view over a face: a press on it chooses the account */
@interface LWClick : NSView { @public id target; SEL action; NSInteger index; } @end
@implementation LWClick - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; } - (void)mouseDown:(NSEvent *)e { [target performSelector: action withObject: self]; } @end

@interface LWController : NSObject <NSTextFieldDelegate> { NSWindow *win, *back; NSArray *accounts; NSInteger chosen; NSSecureTextField *pw; NSTextField *nameLabel, *msg; NSMutableArray *faces; BOOL lock; }
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
- (void)show
{
	NSRect sf = [[NSScreen mainScreen] frame]; win = [[NSWindow alloc] initWithContentRect: sf styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [win setLevel: 2000]; [win setOpaque: YES]; [win setBackgroundColor: [NSColor blackColor]];
	NSView *cv = [win contentView];
	/* the wallpaper and its dimming are a window of their own under the one with the controls (a picture of the size of the screen as a sibling view hid the controls: it is drawn after them) */
	NSImage *wall = [[NSImage alloc] initWithContentsOfFile: @"/System/Library/Desktop Pictures/dark-mode.jpg"];
	if (wall) { [wall setSize: sf.size]; back = [[NSWindow alloc] initWithContentRect: sf styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [back setLevel: 1999]; [back setOpaque: YES]; NSImageView *iv = [[NSImageView alloc] initWithFrame: NSMakeRect(0, 0, sf.size.width, sf.size.height)]; [iv setImage: wall]; [iv setImageScaling: NSImageScaleAxesIndependently]; [back setContentView: iv]; [back orderFront: nil]; }
	[win setOpaque: NO]; [win setBackgroundColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.35]];       /* the Mac blurs the wallpaper here: a dimming stands in */
	CGFloat cx = sf.size.width / 2, cy = sf.size.height / 2; faces = [NSMutableArray array];
	NSUInteger n = [accounts count]; CGFloat pitch = 140, x0 = cx - (n - 1) * pitch / 2;
	for (NSUInteger i = 0; i < n; i++) {
		LWFace *av = [[LWFace alloc] initWithFrame: NSMakeRect(x0 + i * pitch - 48, cy + 10, 96, 96)]; [cv addSubview: av];
		LWClick *b = [[LWClick alloc] initWithFrame: [av frame]]; b->target = self; b->action = @selector(choose:); b->index = (NSInteger)i; [cv addSubview: b]; [faces addObject: av];
		NSTextField *l = [NSTextField labelWithString: accounts[i][@"name"]]; [l setFont: [NSFont boldSystemFontOfSize: 15]]; [l setTextColor: [NSColor whiteColor]]; [l setAlignment: NSCenterTextAlignment]; [l setFrame: NSMakeRect(x0 + i * pitch - 65, cy - 16, 130, 22)]; [cv addSubview: l];
	}
	pw = [[NSSecureTextField alloc] initWithFrame: NSMakeRect(cx - 100, cy - 62, 200, 28)]; [[pw cell] setPlaceholderString: @"Enter Password"]; [pw setAlignment: NSCenterTextAlignment]; [pw setDelegate: self]; [pw setTarget: self]; [pw setAction: @selector(submit:)]; [cv addSubview: pw];
	msg = [NSTextField labelWithString: lock ? @"Enter the password to unlock" : @""]; [msg setTextColor: [NSColor colorWithCalibratedWhite: 1 alpha: 0.7]]; [msg setAlignment: NSCenterTextAlignment]; [msg setFont: [NSFont systemFontOfSize: 12]]; [msg setFrame: NSMakeRect(cx - 160, cy - 92, 320, 18)]; [cv addSubview: msg];
	if (!lock) {
		NSButton *rb = [NSButton buttonWithTitle: @"Restart" target: self action: @selector(restart:)], *sb = [NSButton buttonWithTitle: @"Shut Down" target: self action: @selector(shutdown:)];
		[sb setFrame: NSMakeRect(sf.size.width - 120, 20, 100, 28)]; [rb setFrame: NSMakeRect(sf.size.width - 230, 20, 100, 28)]; [cv addSubview: rb]; [cv addSubview: sb];
	}
	chosen = n == 1 ? 0 : -1; [self refresh]; [win makeKeyAndOrderFront: nil]; [win display]; [NSApp activateIgnoringOtherApps: YES]; if (chosen >= 0) [win makeFirstResponder: pw];
}
- (void)refresh { BOOL one = chosen >= 0; [pw setHidden: !one]; for (NSUInteger k = 0; k < [faces count]; k++) [(LWFace *)faces[k] setAlphaValue: !one || (NSInteger)k == chosen ? 1.0 : 0.45]; if (!lock) [msg setStringValue: one ? @"" : @"Choose an account"]; }
- (void)choose:(LWClick *)b { chosen = b->index; [pw setStringValue: @""]; [self refresh]; [win makeFirstResponder: pw]; }
- (void)submit:(id)s
{
	if (chosen < 0) return; NSString *u = accounts[chosen][@"user"];
	if (Authenticate(u, [pw stringValue])) { printf("%s\n", [u UTF8String]); fflush(stdout); exit(0); }
	[msg setStringValue: @"Incorrect password"]; [pw setStringValue: @""]; [win makeFirstResponder: pw];
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

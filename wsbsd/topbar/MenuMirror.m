/* MenuMirror: the menu bar of the system.  The program that is active publishes its menus (open/OpenMenuBar.m in the Mach-O programs) over a unix socket; the bar shows them: they become the
 * main menu of this application, so the left side of the bar is drawn by appkit/back-wsd/WsdMenuBar.m exactly as before (pear item, the pill, the glass).  Choosing an item sends the action
 * back to the program that owns the menu.
 * Protocol (SOCK_STREAM on WSMENU_SOCKET, default /tmp/wsmenu.sock): frames of a 4 byte big endian length and a JSON object.
 *   program -> bar:  {"cmd":"menus","pid":N,"name":"TextEdit","menus":[{"title":"File","items":[{"id":12,"title":"New","key":"n","mods":1048576,"enabled":true,"state":0,"sep":false,"items":[...]}]}]}
 *                    {"cmd":"activate"}   (the program became the active one: its menus are shown)
 *   bar -> program:  {"cmd":"action","id":12} */
#import <AppKit/AppKit.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <dispatch/dispatch.h>

@interface MMClient : NSObject { @public int fd; dispatch_source_t src; NSMutableData *buf; NSArray *menus; NSString *name; NSMenu *bar; } @end
@implementation MMClient @end

@interface MenuMirror : NSObject
+ (instancetype)shared;
- (void)fire:(NSMenuItem *)it;
@end

static NSMutableArray *sClients;		/* in the order of activation: the last is the one shown */
static MMClient *sShown;
static NSMutableArray *sGrave;		/* menus that were shown stay alive: the libraries are not ARC and still hold them (a released main menu crashed the bar) */

static NSMenu *MenuFromItems(NSArray *items, NSString *title, MenuMirror *target)
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: title ?: @""]; [m setAutoenablesItems: NO];
	for (NSDictionary *d in items) {
		if ([d[@"sep"] boolValue]) { [m addItem: [NSMenuItem separatorItem]]; continue; }
		NSMenuItem *it = [[NSMenuItem alloc] initWithTitle: d[@"title"] ?: @"" action: @selector(fire:) keyEquivalent: d[@"key"] ?: @""];
		[it setTarget: target]; [it setTag: [d[@"id"] integerValue]]; [it setEnabled: d[@"enabled"] ? [d[@"enabled"] boolValue] : YES]; [it setState: [d[@"state"] integerValue]];
		if ([d[@"mods"] unsignedIntegerValue]) [it setKeyEquivalentModifierMask: (NSUInteger)[d[@"mods"] unsignedIntegerValue]];
		NSArray *sub = d[@"items"]; if ([sub isKindOfClass: [NSArray class]] && [sub count]) { [it setAction: NULL]; [it setSubmenu: MenuFromItems(sub, d[@"title"], target)]; }
		[m addItem: it];
	}
	return m;
}

static void MMShow(MMClient *c)
{
	sShown = c; if (!c || !c->menus) return;
	if (c->bar) { if ([NSApp mainMenu] != c->bar) [NSApp setMainMenu: c->bar]; return; }
	NSMenu *bar = [[NSMenu alloc] initWithTitle: c->name ?: @"Main"]; c->bar = bar; if (!sGrave) sGrave = [NSMutableArray new]; [sGrave addObject: bar];
	for (NSDictionary *t in c->menus) {
		NSMenuItem *top = [[NSMenuItem alloc] initWithTitle: t[@"title"] ?: @"" action: NULL keyEquivalent: @""];
		[top setSubmenu: MenuFromItems(t[@"items"], t[@"title"], [MenuMirror shared])]; [bar addItem: top];
	}
	[NSApp setMainMenu: bar];
	/* GNUstep puts the icon and the name of this process ("TopBar") first: the bar belongs to the program that is shown, so that item goes */
	NSString *pn = [[NSProcessInfo processInfo] processName]; NSMenu *mm = [NSApp mainMenu];
	for (NSInteger k = (NSInteger)[mm numberOfItems] - 1; k >= 0; k--) { NSMenuItem *it = [mm itemAtIndex: k]; if ([[it title] isEqual: pn] && ![[it representedObject] isEqual: @"wsd.pear"]) { if (!sGrave) sGrave = [NSMutableArray new]; [sGrave addObject: it]; [mm removeItemAtIndex: k]; }		/* WsdMenuBarPrepare keeps raw pointers of the items it has seen: they must stay alive */ }
	[mm sizeToFit];
}

static void MMDrop(MMClient *c)
{
	dispatch_source_cancel(c->src); [sClients removeObject: c];
	if (sShown == c) { sShown = nil; MMClient *last = [sClients lastObject]; if (last) MMShow(last); }
}

static void MMHandle(MMClient *c, NSDictionary *msg)
{
	NSString *cmd = msg[@"cmd"];
	if ([cmd isEqualToString: @"menus"]) { if (!(c->bar && [msg[@"menus"] isEqual: c->menus])) { c->menus = msg[@"menus"]; c->bar = nil; } c->name = msg[@"name"]; [sClients removeObject: c]; [sClients addObject: c]; MMShow(c); }
	else if ([cmd isEqualToString: @"activate"]) { [sClients removeObject: c]; [sClients addObject: c]; MMShow(c); }
}

static void MMReadable(MMClient *c)
{
	char tmp[8192]; ssize_t n = read(c->fd, tmp, sizeof tmp);
	if (n <= 0) { MMDrop(c); return; }
	[c->buf appendBytes: tmp length: (NSUInteger)n];
	for (;;) {
		if ([c->buf length] < 4) return;
		const unsigned char *p = [c->buf bytes]; NSUInteger len = ((NSUInteger)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
		if (len > (8u << 20)) { MMDrop(c); return; }
		if ([c->buf length] < 4 + len) return;
		NSData *j = [c->buf subdataWithRange: NSMakeRange(4, len)]; [c->buf replaceBytesInRange: NSMakeRange(0, 4 + len) withBytes: NULL length: 0];
		id o = [NSJSONSerialization JSONObjectWithData: j options: 0 error: NULL]; if ([o isKindOfClass: [NSDictionary class]]) MMHandle(c, o);
		if (![sClients containsObject: c]) return;
	}
}

@implementation MenuMirror
+ (instancetype)shared { static MenuMirror *m; if (!m) m = [MenuMirror new]; return m; }
- (void)fire:(NSMenuItem *)it
{
	if (!sShown) return;
	NSData *j = [NSJSONSerialization dataWithJSONObject: @{ @"cmd": @"action", @"id": @([it tag]) } options: 0 error: NULL];
	unsigned char h[4] = { (unsigned char)([j length] >> 24), (unsigned char)([j length] >> 16), (unsigned char)([j length] >> 8), (unsigned char)[j length] };
	write(sShown->fd, h, 4); write(sShown->fd, [j bytes], [j length]);
}
@end

void MenuMirrorStart(void)
{
	const char *path = getenv("WSMENU_SOCKET") ?: "/tmp/wsmenu.sock";
	int ls = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a; memset(&a, 0, sizeof a); a.sun_family = AF_UNIX; strlcpy(a.sun_path, path, sizeof a.sun_path);
	unlink(path); if (bind(ls, (struct sockaddr *)&a, sizeof a) != 0 || listen(ls, 16) != 0) { NSLog(@"menumirror: cannot listen on %s", path); return; }
	chmod(path, 0666); fcntl(ls, F_SETFL, O_NONBLOCK);
	sClients = [NSMutableArray new];
	dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, ls, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(src, ^{
		int fd = accept(ls, NULL, NULL); if (fd < 0) return;
		MMClient *c = [MMClient new]; c->fd = fd; c->buf = [NSMutableData new]; fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
		c->src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_main_queue());
		dispatch_source_set_event_handler(c->src, ^{ MMReadable(c); });
		dispatch_source_set_cancel_handler(c->src, ^{ close(fd); });
		dispatch_resume(c->src); [sClients addObject: c];
	});
	dispatch_resume(src);
	static dispatch_source_t keep; keep = src;
}

/* OpenMenuBar.m — the main menu of the application as a bar at the top of the screen (a window of wsd), pull-down menus (modal loop, submenus open beside the item), actions sent along the responder chain, key equivalents with the command key */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSEvent.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSMenu.h"
#import "NSMenuItem.h"
#import "NSFont.h"
#import "OpenBackend.h"

@interface NSWindow (OpenFrame3) - (CGRect)_openFrame; @end
@interface NSApplication (OpenModalDecl) - (NSInteger)runModalForWindow:(NSWindow *)w; - (void)stopModalWithCode:(NSInteger)c; @end
@interface NSMenuItem (OpenHidden) - (BOOL)isHidden; @end


static void Txt(CGContextRef cg, NSString *t, CGFloat x, CGFloat cy, BOOL bold, CGFloat alpha)
{
    NSDictionary *at = @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:alpha] };
    CGSize ts = [t sizeWithAttributes:at]; [t drawAtPoint:CGPointMake(x, cy - ts.height / 2) withAttributes:at];
}
static CGFloat TxtW(NSString *t, BOOL bold) { return [t sizeWithAttributes:@{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13] }].width; }

/* ---- the action along the responder chain ---- */
static BOOL TrySend(id obj, SEL a, id from) { if (obj && [obj respondsToSelector:a]) { ((void(*)(id, SEL, id))objc_msgSend)(obj, a, from); return YES; } return NO; }
void OpenSendAction(SEL a, id target, id from)
{
    if (!a) return;
    if (target) { TrySend(target, a, from); return; }
    NSWindow *kw = OpenKeyWindow(); id r = [kw firstResponder];
    for (int i = 0; r && i < 30; i++, r = [r nextResponder]) if (TrySend(r, a, from)) return;
    if (TrySend(kw, a, from)) return;
    if (TrySend([kw delegate], a, from)) return;
    if ([kw respondsToSelector:@selector(windowController)] && TrySend([kw performSelector:@selector(windowController)], a, from)) return;
    id wc = [kw respondsToSelector:@selector(windowController)] ? [kw performSelector:@selector(windowController)] : nil;
    if (wc && [wc respondsToSelector:@selector(document)] && TrySend([wc performSelector:@selector(document)], a, from)) return;
    if (TrySend(NSApp, a, from)) return;
    if (TrySend([NSApp delegate], a, from)) return;
    Class dcc = NSClassFromString(@"NSDocumentController"); if (dcc) TrySend([dcc performSelector:@selector(sharedDocumentController)], a, from);
}

/* ---- a list of menu items ---- */
@interface OpenMenuList : NSView { @public NSArray *items; NSInteger hot; CGFloat W; } @end
@implementation OpenMenuList
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)_openGlass { return YES; }			/* the window server draws the material under the (transparent) window */
- (CGFloat)_rowY:(NSInteger)i { CGFloat y = 5; for (NSInteger k = 0; k < i; k++) y += [items[k] isSeparatorItem] ? 11 : 24; return y; }
- (CGFloat)_rowH:(NSInteger)i { return [items[i] isSeparatorItem] ? 11 : 24; }
/* the menus of the theme (WsdMacTheme.m): rows 24 pt, separators 11, 5 pt above and below, the highlighted row the accent 5 pt in from the sides with radius 8, separators 16 pt in (white 14 %), text controlText */
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    CGRect b = [self bounds];
    for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
        NSMenuItem *it = items[i]; CGFloat top = [self _rowY:i], h = [self _rowH:i];
        CGRect r = CGRectMake(0, b.size.height - top - h, b.size.width, h);
        if ([it isSeparatorItem]) { CGContextSetRGBFillColor(cg, 1, 1, 1, 0.14); CGContextFillRect(cg, CGRectMake(16, r.origin.y + h / 2 - 0.5, b.size.width - 31, 1)); continue; }
        BOOL en = [it isEnabled], isHot = i == hot && en;
        if (isHot) { CGPathRef hp = CGPathCreateWithRoundedRect(CGRectInset(r, 5, 0), 8, 8, NULL); CGContextSetRGBFillColor(cg, 0, 122 / 255.0, 1, 1); CGContextAddPath(cg, hp); CGContextFillPath(cg); CGPathRelease(hp); }
        CGFloat a = en ? (isHot ? 1.0 : 0.85) : 0.25, cy = r.origin.y + h / 2;
        if ([it state] == 1) Txt(cg, @"✓", 7, cy, NO, a);
        Txt(cg, [it title] ?: @"", 24, cy, NO, a);
        NSString *k = [it keyEquivalent]; if ([k length]) { NSString *ks = [@"⌘" stringByAppendingString:[k uppercaseString]]; Txt(cg, ks, b.size.width - 16 - TxtW(ks, NO), cy, NO, a * 0.7); }
        if ([it submenu]) Txt(cg, @"›", b.size.width - 22, cy, NO, isHot ? 1.0 : (en ? 0.6 : 0.25));
    }
}
- (NSInteger)_idx:(NSEvent *)e { CGPoint p = [e locationInWindow]; CGFloat y = [self frame].size.height - p.y; for (NSInteger i = 0; i < (NSInteger)[items count]; i++) { CGFloat t = [self _rowY:i]; if (y >= t && y < t + [self _rowH:i]) return [items[i] isSeparatorItem] ? -1 : i; } return -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i != hot) { hot = i; [self display]; } }
- (void)mouseDown:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i >= 0 && [items[i] isEnabled]) [NSApp stopModalWithCode:1000 + i]; }
- (void)keyDown:(NSEvent *)e { if ([e keyCode] == 53) [NSApp stopModalWithCode:-1000]; }
- (void)_openFocusOut { [NSApp stopModalWithCode:-1000]; }
@end

/* the item chosen in a menu shown at (x, y): y up, the top left corner of the list; submenus open to the right of their item */
NSMenuItem *PopupMenu(NSMenu *m, CGFloat x, CGFloat y)
{
    NSMutableArray *vis = [NSMutableArray new]; for (NSMenuItem *it in [m itemArray]) if (![it respondsToSelector:@selector(isHidden)] || ![it isHidden]) [vis addObject:it];
    CGFloat W = 120; for (NSMenuItem *it in vis) { CGFloat w = 21 + TxtW([it title] ?: @"", NO) + ([[it keyEquivalent] length] ? 44 : 0) + ([it submenu] ? 20 : 0) + 24; if (w > W) W = w; }
    CGFloat H = 10; for (NSMenuItem *it in vis) H += [it isSeparatorItem] ? 11 : 24;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(x, y - H, W, H) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    OpenMenuList *v = [[OpenMenuList alloc] initWithFrame:CGRectMake(0, 0, W, H)]; v->items = vis; v->hot = -1; v->W = W; [w setContentView:v]; [w makeFirstResponder:v];
    NSInteger r = [NSApp runModalForWindow:w]; if (r < 1000) return nil;
    NSMenuItem *it = vis[r - 1000];
    if ([it submenu]) { CGFloat top = 5; for (NSInteger k = 0; k < r - 1000; k++) top += [vis[k] isSeparatorItem] ? 11 : 24; return PopupMenu([it submenu], x + W - 4, y - top + 4); }
    return it;
}

/* ---- the bar ---- */
static NSMenu *sMenu; static NSMutableArray *sRects; static NSWindow *sBarWin;
@interface OpenBarView : NSView @end
@implementation OpenBarView
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    CGRect b = [self bounds];
    CGContextSetRGBFillColor(cg, 30 / 255.0, 30 / 255.0, 32 / 255.0, 0.96); CGContextFillRect(cg, b);
    CGContextSetRGBFillColor(cg, 1, 1, 1, 0.1); CGContextFillRect(cg, CGRectMake(0, 0, b.size.width, 1));
    sRects = [NSMutableArray new]; CGFloat x = 14; NSInteger i = 0;
    for (NSMenuItem *it in [sMenu itemArray]) {
        NSString *t = [it title]; if (![t length] && [it submenu]) t = [[it submenu] title];
        BOOL bold = i == 0; CGFloat w = TxtW(t ?: @"", bold);
        [sRects addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)x - 8, (NSUInteger)w + 16)]];
        Txt(cg, t ?: @"", x, b.size.height / 2, bold, 0.92); x += w + 24; i++;
    }
}
- (void)mouseDown:(NSEvent *)e
{
    CGFloat px = [e locationInWindow].x; NSInteger i = 0;
    for (NSValue *v in sRects) { NSRange r = [v rangeValue]; if (px >= r.location && px < r.location + r.length) break; i++; }
    if (i >= (NSInteger)[sRects count]) return;
    NSMenuItem *top = [sMenu itemArray][i]; if (![top submenu]) return;
    NSRange r = [sRects[i] rangeValue];
    NSMenuItem *chosen = PopupMenu([top submenu], r.location, [sBarWin _openFrame].origin.y + 2);
    if (chosen) OpenSendAction([chosen action], [chosen target], chosen);
}
@end

/* ---- the menu bar of the system (topbar/MenuMirror.m): the menus are published over /tmp/wsmenu.sock, the actions come back ---- */
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
static int sBarFd = -1; static NSMutableDictionary *sItemsById;
static id TargetFor(SEL a, id explicit)
{
    if (explicit) return [explicit respondsToSelector:a] ? explicit : nil;
    NSWindow *kw = OpenKeyWindow(); id r = [kw firstResponder];
    for (int i = 0; r && i < 30; i++, r = [r nextResponder]) if ([r respondsToSelector:a]) return r;
    id cands[6] = { kw, [kw delegate], [kw respondsToSelector:@selector(windowController)] ? [kw performSelector:@selector(windowController)] : nil, nil, NSApp, [NSApp delegate] };
    id wc = cands[2]; if (wc && [wc respondsToSelector:@selector(document)]) cands[3] = [wc performSelector:@selector(document)];
    for (int i = 0; i < 6; i++) if (cands[i] && [cands[i] respondsToSelector:a]) return cands[i];
    Class dcc = NSClassFromString(@"NSDocumentController"); id dc = dcc ? [dcc performSelector:@selector(sharedDocumentController)] : nil; return dc && [dc respondsToSelector:a] ? dc : nil;
}
static BOOL ItemEnabled(NSMenuItem *it)
{
    if (![it isEnabled]) return NO;
    if (![it action]) return YES;			/* a submenu title */
    id t = TargetFor([it action], [it target]); if (!t) return NO;
    if ([t respondsToSelector:@selector(validateMenuItem:)]) return ((BOOL(*)(id, SEL, id))objc_msgSend)(t, @selector(validateMenuItem:), it);
    return YES;
}
static NSArray *Describe(NSMenu *m, NSMutableDictionary *ids)
{
    NSMutableArray *out = [NSMutableArray new];
    for (NSMenuItem *it in [m itemArray]) {
        if ([it isSeparatorItem]) { [out addObject:@{ @"sep": @YES }]; continue; }
        if ([it respondsToSelector:@selector(isHidden)] && [it isHidden]) continue;
        NSUInteger n = [ids count] + 1; ids[@(n)] = it;
        NSMutableDictionary *d = [@{ @"id": @(n), @"title": [it title] ?: @"", @"key": [it keyEquivalent] ?: @"", @"mods": @(1048576), @"enabled": @(ItemEnabled(it)), @"state": @([it state]) } mutableCopy];
        if ([it submenu]) d[@"items"] = Describe([it submenu], ids);
        [out addObject:d];
    }
    return out;
}
static void SendFrame(NSDictionary *o)
{
    NSData *j = [NSJSONSerialization dataWithJSONObject:o options:0 error:NULL]; if (!j || sBarFd < 0) return;
    unsigned char h[4] = { (unsigned char)([j length] >> 24), (unsigned char)([j length] >> 16), (unsigned char)([j length] >> 8), (unsigned char)[j length] };
    write(sBarFd, h, 4); write(sBarFd, [j bytes], [j length]);
}
void OpenMenuPublish(BOOL full)
{
    if (sBarFd < 0) return;
    sItemsById = [NSMutableDictionary new]; NSMutableArray *tops = [NSMutableArray new];
    for (NSMenuItem *t in [[NSApp mainMenu] itemArray]) { NSString *ti = [t title]; if (![ti length] && [t submenu]) ti = [[t submenu] title]; if ([t submenu]) [tops addObject:@{ @"title": ti ?: @"", @"items": Describe([t submenu], sItemsById) }]; }
    NSString *name = [[NSProcessInfo processInfo] processName];
    SendFrame(@{ @"cmd": @"menus", @"pid": @(getpid()), @"name": name, @"menus": tops });
}
static BOOL ConnectBar(void)
{
    const char *path = getenv("WSMENU_SOCKET") ?: "/tmp/wsmenu.sock";
    int fd = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a; memset(&a, 0, sizeof a); a.sun_family = AF_UNIX; strlcpy(a.sun_path, path, sizeof a.sun_path);
    if (connect(fd, (struct sockaddr *)&a, sizeof a) != 0) { close(fd); return NO; }
    sBarFd = fd;
    dispatch_async(dispatch_queue_create("open.menubar", DISPATCH_QUEUE_SERIAL), ^{
        NSMutableData *buf = [NSMutableData new];
        for (;;) {
            char tmp[4096]; ssize_t n = read(sBarFd, tmp, sizeof tmp); if (n <= 0) { sBarFd = -1; return; }
            [buf appendBytes:tmp length:(NSUInteger)n];
            while ([buf length] >= 4) {
                const unsigned char *p = [buf bytes]; NSUInteger len = ((NSUInteger)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]; if ([buf length] < 4 + len) break;
                id o = [NSJSONSerialization JSONObjectWithData:[buf subdataWithRange:NSMakeRange(4, len)] options:0 error:NULL]; [buf replaceBytesInRange:NSMakeRange(0, 4 + len) withBytes:NULL length:0];
                if ([o isKindOfClass:[NSDictionary class]] && [o[@"cmd"] isEqualToString:@"action"]) {
                    NSNumber *idn = o[@"id"];
                    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ NSMenuItem *it = sItemsById[idn]; if (it && [it action]) OpenSendAction([it action], [it target], it); OpenMenuPublish(YES); });
                    CFRunLoopWakeUp(CFRunLoopGetMain());
                }
            }
        }
    });
    return YES;
}

void OpenMenuBarShow(void)
{
    if (!sMenu && ConnectBar()) { OpenMenuPublish(YES); if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: menus published to the system menu bar\n"); return; }
    if (sBarFd >= 0) { OpenMenuPublish(YES); return; }
    sMenu = [NSApp mainMenu]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: menubar: mainMenu %p items %lu\n", (__bridge void *)sMenu, (unsigned long)[[sMenu itemArray] count]);
    if (!sMenu || ![[sMenu itemArray] count]) return;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(0, 800 - 24, 1280, 24) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    [w setContentView:[[OpenBarView alloc] initWithFrame:CGRectMake(0, 0, 1280, 24)]]; sBarWin = w;
    [w makeKeyAndOrderFront:nil];
}

/* command + key: the item of the menus with that key equivalent */
static NSMenuItem *FindKey(NSMenu *m, NSString *k)
{
    for (NSMenuItem *it in [m itemArray]) {
        if ([[it keyEquivalent] caseInsensitiveCompare:k] == NSOrderedSame && [[it keyEquivalent] length] && [it isEnabled]) return it;
        if ([it submenu]) { NSMenuItem *f = FindKey([it submenu], k); if (f) return f; }
    }
    return nil;
}
BOOL OpenMenuKeyEquivalent(int kc, BOOL shift)
{
    static const char *pl = "asdfhgzxcv\0bqweryt123465=97-80]ou[ip\0lj'k;\\,/nm.\0\0`";
    NSMenu *root = sMenu ?: [NSApp mainMenu];		/* the system bar publishes the main menu: the key equivalents are those of the app's menu */
    if (!root || kc >= 51 || !pl[kc]) return NO;
    NSMenuItem *it = FindKey(root, [NSString stringWithFormat:@"%c", pl[kc]]); if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: keyequiv %c -> %s action %s\n", pl[kc], it ? [[it title] UTF8String] : "none", it && [it action] ? sel_getName([it action]) : "-"); if (!it || ![it action]) return NO;
    OpenSendAction([it action], [it target], it); return YES;
}

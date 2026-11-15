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
- (CGFloat)_rowY:(NSInteger)i { CGFloat y = 5; for (NSInteger k = 0; k < i; k++) y += [items[k] isSeparatorItem] ? 9 : 22; return y; }
- (CGFloat)_rowH:(NSInteger)i { return [items[i] isSeparatorItem] ? 9 : 22; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    CGRect b = [self bounds];
    CGPathRef p = CGPathCreateWithRoundedRect(CGRectInset(b, 0.5, 0.5), 10, 10, NULL);
    CGContextSetRGBFillColor(cg, 44 / 255.0, 44 / 255.0, 46 / 255.0, 1); CGContextAddPath(cg, p); CGContextFillPath(cg);
    CGContextSetRGBStrokeColor(cg, 1, 1, 1, 0.14); CGContextAddPath(cg, p); CGContextStrokePath(cg); CGPathRelease(p);
    for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
        NSMenuItem *it = items[i]; CGFloat top = [self _rowY:i], h = [self _rowH:i];
        CGRect r = CGRectMake(5, b.size.height - top - h, b.size.width - 10, h);
        if ([it isSeparatorItem]) { CGContextSetRGBFillColor(cg, 1, 1, 1, 0.14); CGContextFillRect(cg, CGRectMake(14, r.origin.y + h / 2, b.size.width - 28, 1)); continue; }
        if (i == hot) { CGPathRef hp = CGPathCreateWithRoundedRect(r, 5, 5, NULL); CGContextSetRGBFillColor(cg, 0, 122 / 255.0, 1, 1); CGContextAddPath(cg, hp); CGContextFillPath(cg); CGPathRelease(hp); }
        CGFloat a = [it isEnabled] ? 0.92 : 0.35, cy = r.origin.y + h / 2;
        if ([it state] == 1) Txt(cg, @"✓", 12, cy, NO, a);
        Txt(cg, [it title] ?: @"", 26, cy, NO, a);
        NSString *k = [it keyEquivalent]; if ([k length]) Txt(cg, [@"⌘" stringByAppendingString:[k uppercaseString]], b.size.width - 14 - TxtW([@"⌘" stringByAppendingString:[k uppercaseString]], NO), cy, NO, a * 0.7);
        if ([it submenu]) Txt(cg, @"›", b.size.width - 20, cy, NO, a);
    }
}
- (NSInteger)_idx:(NSEvent *)e { CGPoint p = [e locationInWindow]; CGFloat y = [self frame].size.height - p.y; for (NSInteger i = 0; i < (NSInteger)[items count]; i++) { CGFloat t = [self _rowY:i]; if (y >= t && y < t + [self _rowH:i]) return [items[i] isSeparatorItem] ? -1 : i; } return -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i != hot) { hot = i; [self display]; } }
- (void)mouseDown:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i >= 0 && [items[i] isEnabled]) [NSApp stopModalWithCode:1000 + i]; else if (i < 0) { } }
- (void)keyDown:(NSEvent *)e { if ([e keyCode] == 53) [NSApp stopModalWithCode:-1000]; }
- (void)_openFocusOut { [NSApp stopModalWithCode:-1000]; }
@end

/* the item chosen in a menu shown at (x, y): y up, the top left corner of the list; submenus open to the right of their item */
static NSMenuItem *PopupMenu(NSMenu *m, CGFloat x, CGFloat y)
{
    NSMutableArray *vis = [NSMutableArray new]; for (NSMenuItem *it in [m itemArray]) if (![it respondsToSelector:@selector(isHidden)] || ![it isHidden]) [vis addObject:it];
    CGFloat W = 160; for (NSMenuItem *it in vis) { CGFloat w = 26 + TxtW([it title] ?: @"", NO) + ([[it keyEquivalent] length] ? 50 : 0) + ([it submenu] ? 20 : 0) + 16; if (w > W) W = w; }
    CGFloat H = 10; for (NSMenuItem *it in vis) H += [it isSeparatorItem] ? 9 : 22;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(x, y - H, W, H) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    OpenMenuList *v = [[OpenMenuList alloc] initWithFrame:CGRectMake(0, 0, W, H)]; v->items = vis; v->hot = -1; v->W = W; [w setContentView:v]; [w makeFirstResponder:v];
    NSInteger r = [NSApp runModalForWindow:w]; if (r < 1000) return nil;
    NSMenuItem *it = vis[r - 1000];
    if ([it submenu]) { CGFloat top = 5; for (NSInteger k = 0; k < r - 1000; k++) top += [vis[k] isSeparatorItem] ? 9 : 22; return PopupMenu([it submenu], x + W - 4, y - top + 4); }
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

void OpenMenuBarShow(void)
{
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
    if (!sMenu || kc >= 51 || !pl[kc]) return NO;
    NSMenuItem *it = FindKey(sMenu, [NSString stringWithFormat:@"%c", pl[kc]]); if (!it || ![it action]) return NO;
    OpenSendAction([it action], [it target], it); return YES;
}

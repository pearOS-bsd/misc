/* NSMenuItem additions of macOS's AppKit that GNUstep lacks, and what they do in the menu: a hidden item takes no room and is not found by key equivalents (unless it allows that),
 * an item with a view shows that view in its row and takes the view's height, parentItem / highlighted / section headers (title in the secondary colour, not selectable). Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static char kHidden, kAllowsHidden, kView, kHeader;
@interface NSMenuView (WsdMenuItemPrivate)
- (CGFloat)heightForItem:(NSInteger)i;
- (NSMenuItemCell *)menuItemCellForItemAtIndex:(NSInteger)i;
@end

@implementation NSMenuItem (WsdMenuItem)
- (BOOL)isHidden { return [objc_getAssociatedObject(self, &kHidden) boolValue]; }
- (void)setHidden:(BOOL)h
{
	if (h == [self isHidden]) return;
	objc_setAssociatedObject(self, &kHidden, [NSNumber numberWithBool: h], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[[self menu] itemChanged: self];
	[[[self menu] menuRepresentation] sizeToFit];
}
- (BOOL)allowsKeyEquivalentWhenHidden { return [objc_getAssociatedObject(self, &kAllowsHidden) boolValue]; }
- (void)setAllowsKeyEquivalentWhenHidden:(BOOL)b { objc_setAssociatedObject(self, &kAllowsHidden, [NSNumber numberWithBool: b], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSMenuItem *)parentItem
{
	NSMenu *m = [[self menu] supermenu];
	if (!m) return nil;
	NSInteger i = [m indexOfItemWithSubmenu: [self menu]];
	return i >= 0 ? [m itemAtIndex: i] : nil;
}
- (BOOL)isHiddenOrHasHiddenAncestor { for (NSMenuItem *i = self; i; i = [i parentItem]) if ([i isHidden]) return YES; return NO; }
- (BOOL)isHighlighted
{
	NSMenu *m = [self menu]; if (!m) return NO;
	return [[m menuRepresentation] highlightedItemIndex] == [m indexOfItem: self];
}
- (NSView *)view { return objc_getAssociatedObject(self, &kView); }
- (void)setView:(NSView *)v
{
	NSView *old = [self view];
	if (old == v) return;
	[old removeFromSuperview];
	objc_setAssociatedObject(self, &kView, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[[self menu] itemChanged: self];
	[[[self menu] menuRepresentation] sizeToFit];
}
- (BOOL)isSectionHeader { return [objc_getAssociatedObject(self, &kHeader) boolValue]; }
+ (NSMenuItem *)sectionHeaderWithTitle:(NSString *)t
{
	NSMenuItem *i = [[[NSMenuItem alloc] initWithTitle: t action: NULL keyEquivalent: @""] autorelease];
	objc_setAssociatedObject(i, &kHeader, [NSNumber numberWithBool: YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[i setEnabled: NO];
	return i;
}
@end

/* placeholders: they answer the selector but keep a value only */
@implementation NSMenuItem (WsdAppKitPlaceholder)
- (BOOL)allowsAutomaticKeyEquivalentLocalization { return YES; }
- (void)setAllowsAutomaticKeyEquivalentLocalization:(BOOL)b {}
- (BOOL)allowsAutomaticKeyEquivalentMirroring { return YES; }
- (void)setAllowsAutomaticKeyEquivalentMirroring:(BOOL)b {}
@end

static IMP origHeight, origKeyEq, origSize;
static CGFloat wsdItemHeight(NSMenuView *self, SEL _cmd, NSInteger i)
{
	NSMenuItem *it = [[[self menuItemCellForItemAtIndex: i] menuItem] retain];
	CGFloat h;
	if ([it isHidden]) h = 0;
	else if ([it view]) h = [[it view] frame].size.height;
	else h = ((CGFloat (*)(id, SEL, NSInteger))origHeight)(self, _cmd, i);
	[it release];
	return h;
}
static NSString *wsdItemKeyEq(NSMenuItem *self, SEL _cmd)
{
	if ([self isHidden] && ![self allowsKeyEquivalentWhenHidden]) return @"";
	return ((NSString *(*)(id, SEL))origKeyEq)(self, _cmd);
}
/* after the layout: put the items' views in their rows */
static void wsdItemSize(NSMenuView *self, SEL _cmd)
{
	((void (*)(id, SEL))origSize)(self, _cmd);
	NSMenu *m = [self menu];
	for (NSInteger i = 0; i < [m numberOfItems]; i++)
	{
		NSView *v = [[m itemAtIndex: i] view];
		if (!v) continue;
		if ([v superview] != self) [self addSubview: v];
		NSRect r = [self rectOfItemAtIndex: i];
		[v setFrame: NSMakeRect(r.origin.x, r.origin.y, r.size.width, [v frame].size.height)];
	}
}
@interface WsdMenuItemInit : NSObject @end
@implementation WsdMenuItemInit
+ (void)load
{
	Method m;
	if ((m = class_getInstanceMethod([NSMenuView class], @selector(heightForItem:)))) origHeight = method_setImplementation(m, (IMP)wsdItemHeight);
	if ((m = class_getInstanceMethod([NSMenuItem class], @selector(keyEquivalent)))) origKeyEq = method_setImplementation(m, (IMP)wsdItemKeyEq);
	/* sizeToFit is already replaced by the theme (WsdMacTheme.m) when it loads; chain behind whatever is installed when the first menu view is made */
	if ((m = class_getInstanceMethod([NSMenuView class], @selector(sizeToFit)))) origSize = method_setImplementation(m, (IMP)wsdItemSize);
}
@end

/* NSMenuItemBadge (macOS 14): a count, a string or a typed count at the trailing edge of the row, drawn as a pill (updates grey, new items blue, alerts red) after the cell is drawn.
 * The colours and sizes are estimated, not measured on a Mac yet. */
@interface NSMenuItemBadge : NSObject <NSCopying> { NSInteger _count; NSInteger _type; NSString *_string; } @end
@implementation NSMenuItemBadge
- (id)initWithCount:(NSInteger)c type:(NSInteger)t { if ((self = [super init])) { _count = c; _type = t; _string = [[NSString stringWithFormat: @"%ld", (long)c] retain]; } return self; }
- (id)initWithCount:(NSInteger)c { return [self initWithCount: c type: 0]; }
- (id)initWithString:(NSString *)s { if ((self = [super init])) _string = [s copy]; return self; }
+ (id)updatesWithCount:(NSInteger)c { return [[[self alloc] initWithCount: c type: 1] autorelease]; }
+ (id)newItemsWithCount:(NSInteger)c { return [[[self alloc] initWithCount: c type: 2] autorelease]; }
+ (id)alertsWithCount:(NSInteger)c { return [[[self alloc] initWithCount: c type: 3] autorelease]; }
- (NSInteger)itemCount { return _count; }
- (NSInteger)type { return _type; }
- (NSString *)stringValue { return _string; }
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (void)dealloc { [_string release]; [super dealloc]; }
@end
static char kBadge;
@implementation NSMenuItem (WsdMenuItemBadge)
- (NSMenuItemBadge *)badge { return objc_getAssociatedObject(self, &kBadge); }
- (void)setBadge:(NSMenuItemBadge *)b { objc_setAssociatedObject(self, &kBadge, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [[self menu] itemChanged: self]; }
@end
static IMP origCellDraw;
static void wsdCellDraw(NSMenuItemCell *self, SEL _cmd, NSRect f, NSView *v)
{
	((void (*)(id, SEL, NSRect, NSView *))origCellDraw)(self, _cmd, f, v);
	NSMenuItemBadge *b = [[self menuItem] badge]; if (!b || ![b stringValue]) return;
	NSDictionary *at = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 11], NSFontAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	NSSize ts = [[b stringValue] sizeWithAttributes: at];
	CGFloat w = fmax(16, ts.width + 10), h = 16;
	NSRect pill = NSMakeRect(NSMaxX(f) - w - 10, NSMidY(f) - h / 2, w, h);
	NSColor *col = [b type] == 3 ? [NSColor colorWithCalibratedRed: 1.0 green: 0.27 blue: 0.23 alpha: 1] : [b type] == 2 ? [NSColor colorWithCalibratedRed: 0.0 green: 0.48 blue: 1.0 alpha: 1] : [NSColor colorWithCalibratedWhite: 0.55 alpha: 1];
	[col set]; [[NSBezierPath bezierPathWithRoundedRect: pill xRadius: h / 2 yRadius: h / 2] fill];
	[[b stringValue] drawAtPoint: NSMakePoint(NSMidX(pill) - ts.width / 2, NSMidY(pill) - ts.height / 2) withAttributes: at];
}
@interface WsdMenuBadgeInit : NSObject @end
@implementation WsdMenuBadgeInit
+ (void)load { Method m = class_getInstanceMethod([NSMenuItemCell class], @selector(drawWithFrame:inView:)); if (m) { origCellDraw = method_getImplementation(m); class_replaceMethod([NSMenuItemCell class], @selector(drawWithFrame:inView:), (IMP)wsdCellDraw, method_getTypeEncoding(m)); } }   /* replaced on NSMenuItemCell itself: the method may be inherited from NSButtonCell */
@end

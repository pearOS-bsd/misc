/* NSView tracking areas (addTrackingArea: and company) on top of GNUstep's tracking rectangles, which are what the window checks on every mouse move. What the modern API adds is done here:
 * the options (enter / exit, cursor update, the active-in-key-window / app / always conditions, in-visible-rect areas that follow the view), updateTrackingAreas after every change of the geometry,
 * and NSEvent's trackingArea. The rectangle's owner is a proxy that applies the options before it forwards. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static char kAreas, kTag, kProxy, kObs;

@interface WsdTrackOwner : NSObject { @public id owner; NSTrackingAreaOptions opts; }
@end
@implementation WsdTrackOwner
- (BOOL)active:(NSEvent *)e
{
	NSWindow *w = [e window];
	if (opts & NSTrackingActiveAlways) return YES;
	if (opts & NSTrackingActiveInActiveApp) return [NSApp isActive];
	if (opts & NSTrackingActiveInKeyWindow) return [w isKeyWindow];
	if (opts & NSTrackingActiveWhenFirstResponder) return [w isKeyWindow] && [[w firstResponder] isKindOfClass: [NSView class]] && owner == [w firstResponder];
	return [w isKeyWindow];
}
- (void)mouseEntered:(NSEvent *)e
{
	if (![self active: e]) return;
	if ((opts & NSTrackingMouseEnteredAndExited) && [owner respondsToSelector: @selector(mouseEntered:)]) [owner mouseEntered: e];
	if ((opts & NSTrackingCursorUpdate) && [owner respondsToSelector: @selector(cursorUpdate:)]) [owner cursorUpdate: e];
}
- (void)mouseExited:(NSEvent *)e
{
	if (![self active: e]) return;
	if ((opts & NSTrackingMouseEnteredAndExited) && [owner respondsToSelector: @selector(mouseExited:)]) [owner mouseExited: e];
}
@end

static NSMapTable *byTag; /* tracking rectangle tag -> area, not retained */
@implementation NSEvent (WsdTracking)
- (NSTrackingArea *)trackingArea { return ([self type] == NSMouseEntered || [self type] == NSMouseExited || [self type] == NSCursorUpdate) ? (NSTrackingArea *)NSMapGet(byTag, (void *)(intptr_t)[self trackingNumber]) : nil; }
@end

@interface NSView (WsdTrackingPrivate)
- (void)wsdTrackingRefresh:(NSNotification *)n;
@end

@implementation NSView (WsdTracking)
- (NSArray *)trackingAreas { return objc_getAssociatedObject(self, &kAreas) ?: [NSArray array]; }
- (NSRect)wsdAreaRect:(NSTrackingArea *)a { return ([a options] & NSTrackingInVisibleRect) ? [self visibleRect] : [a rect]; }
- (void)wsdInstall:(NSTrackingArea *)a
{
	WsdTrackOwner *p = [[WsdTrackOwner alloc] init];
	p->owner = [a owner]; p->opts = [a options];
	NSTrackingRectTag t = [self addTrackingRect: [self wsdAreaRect: a] owner: p userData: NULL assumeInside: ([a options] & NSTrackingAssumeInside) != 0];
	if (!byTag) byTag = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 16);
	NSMapInsert(byTag, (void *)(intptr_t)t, a);
	objc_setAssociatedObject(a, &kTag, [NSNumber numberWithInteger: t], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(a, &kProxy, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[p release];
	if ([a options] & NSTrackingMouseMoved) [[self window] setAcceptsMouseMovedEvents: YES];
}
- (void)wsdUninstall:(NSTrackingArea *)a
{
	NSNumber *t = objc_getAssociatedObject(a, &kTag);
	if (t) { NSMapRemove(byTag, (void *)(intptr_t)[t integerValue]); [self removeTrackingRect: [t integerValue]]; }
	objc_setAssociatedObject(a, &kTag, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(a, &kProxy, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)addTrackingArea:(NSTrackingArea *)a
{
	NSMutableArray *m = [NSMutableArray arrayWithArray: [self trackingAreas]];
	if ([m containsObject: a]) return;
	[m addObject: a];
	objc_setAssociatedObject(self, &kAreas, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self wsdInstall: a];
	if (!objc_getAssociatedObject(self, &kObs))
	{
		objc_setAssociatedObject(self, &kObs, [NSNumber numberWithBool: YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[self setPostsFrameChangedNotifications: YES]; [self setPostsBoundsChangedNotifications: YES];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(wsdTrackingRefresh:) name: NSViewFrameDidChangeNotification object: self];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(wsdTrackingRefresh:) name: NSViewBoundsDidChangeNotification object: self];
	}
}
- (void)removeTrackingArea:(NSTrackingArea *)a
{
	NSMutableArray *m = [NSMutableArray arrayWithArray: [self trackingAreas]];
	if (![m containsObject: a]) return;
	[a retain]; [m removeObject: a];
	objc_setAssociatedObject(self, &kAreas, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self wsdUninstall: a]; [a release];
}
/* the default does nothing here; the views that override it (as Apple's documentation suggests) remove and add their areas, and we re-seat the in-visible-rect ones */
- (void)updateTrackingAreas {}
- (void)wsdTrackingRefresh:(NSNotification *)n
{
	[self updateTrackingAreas];
	for (NSTrackingArea *a in [NSArray arrayWithArray: [self trackingAreas]])
		if ([a options] & NSTrackingInVisibleRect) { [a retain]; [self wsdUninstall: a]; [self wsdInstall: a]; [a release]; }
}
@end

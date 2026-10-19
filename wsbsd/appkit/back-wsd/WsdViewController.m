/* NSViewController of macOS 10.10+ that GNUstep lacks: the hierarchy of child view controllers (add / insert / remove, parentViewController), presentation as sheet, modal window, popover or through an
 * animator, dismissal, presentingViewController / presentedViewControllers, preferredContentSize (applied to the window the controller is presented in), loadViewIfNeeded / viewIfLoaded and
 * transitionFromViewController:toViewController:. A presented controller's view is the content view of a window that keeps the controller alive. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static char kKids, kParent, kPresented, kPresenting, kWin, kSize, kKind, kPop;
enum { KindSheet = 1, KindModal, KindPopover, KindAnimator };
@interface NSViewController (WsdPrivate) - (NSMutableArray *)wsdKids; @end

@implementation NSViewController (WsdViewController)
- (NSMutableArray *)wsdKids { NSMutableArray *m = objc_getAssociatedObject(self, &kKids); if (!m) { m = [NSMutableArray array]; objc_setAssociatedObject(self, &kKids, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return m; }
- (NSArray *)childViewControllers { return [NSArray arrayWithArray: [self wsdKids]]; }
- (void)setChildViewControllers:(NSArray *)a { for (NSViewController *c in [NSArray arrayWithArray: [self wsdKids]]) [c removeFromParentViewController]; for (NSViewController *c in a) [self addChildViewController: c]; }
- (NSViewController *)parentViewController { return objc_getAssociatedObject(self, &kParent); }
- (void)insertChildViewController:(NSViewController *)c atIndex:(NSInteger)i
{
	if ([c parentViewController]) [c removeFromParentViewController];
	NSMutableArray *k = [self wsdKids]; if (i > (NSInteger)[k count]) i = [k count];
	[k insertObject: c atIndex: i]; objc_setAssociatedObject(c, &kParent, self, OBJC_ASSOCIATION_ASSIGN);
}
- (void)addChildViewController:(NSViewController *)c { [self insertChildViewController: c atIndex: [[self wsdKids] count]]; }
- (void)removeChildViewControllerAtIndex:(NSInteger)i { if (i >= 0 && i < (NSInteger)[[self wsdKids] count]) [[[self wsdKids] objectAtIndex: i] removeFromParentViewController]; }
- (void)removeFromParentViewController
{
	NSViewController *p = [self parentViewController]; if (!p) return;
	[self retain]; [[p wsdKids] removeObject: self]; objc_setAssociatedObject(self, &kParent, nil, OBJC_ASSOCIATION_ASSIGN); [self release];
}
- (void)loadViewIfNeeded { (void)[self view]; }
- (NSView *)viewIfLoaded { return [self isViewLoaded] ? [self view] : nil; }

- (NSSize)preferredContentSize { NSValue *v = objc_getAssociatedObject(self, &kSize); return v ? [v sizeValue] : NSZeroSize; }
- (void)setPreferredContentSize:(NSSize)s
{
	objc_setAssociatedObject(self, &kSize, [NSValue valueWithSize: s], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	NSWindow *w = objc_getAssociatedObject(self, &kWin);
	if (w && s.width > 0 && s.height > 0) { NSRect f = [w frameRectForContentRect: NSMakeRect(0, 0, s.width, s.height)]; NSRect old = [w frame]; f.origin = NSMakePoint(old.origin.x, NSMaxY(old) - f.size.height); [w setFrame: f display: YES]; }
	NSViewController *p = [self parentViewController]; if (p && [p respondsToSelector: @selector(preferredContentSizeDidChangeForViewController:)]) [p preferredContentSizeDidChangeForViewController: self];
}
- (void)preferredContentSizeDidChangeForViewController:(NSViewController *)c {}
- (void)viewWillTransitionToSize:(NSSize)s {}

- (NSViewController *)presentingViewController { return objc_getAssociatedObject(self, &kPresenting); }
- (NSArray *)presentedViewControllers { NSArray *a = objc_getAssociatedObject(self, &kPresented); return a ? [NSArray arrayWithArray: a] : [NSArray array]; }
- (NSWindow *)wsdMakeWindowFor:(NSViewController *)vc style:(NSUInteger)style
{
	NSSize s = [vc preferredContentSize]; NSView *v = [vc view]; if (s.width <= 0 || s.height <= 0) s = [v frame].size;
	NSWindow *w = [[[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, s.width, s.height) styleMask: style backing: NSBackingStoreBuffered defer: NO] autorelease];
	[w setReleasedWhenClosed: NO]; [w setContentView: v]; if ([[vc title] length]) [w setTitle: [vc title]];
	objc_setAssociatedObject(w, &kPresented, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);               /* the window keeps its controller */
	objc_setAssociatedObject(vc, &kWin, w, OBJC_ASSOCIATION_ASSIGN);
	return w;
}
- (void)wsdRegisterPresented:(NSViewController *)vc kind:(int)k
{
	NSMutableArray *a = objc_getAssociatedObject(self, &kPresented); if (!a) { a = [NSMutableArray array]; objc_setAssociatedObject(self, &kPresented, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	[a addObject: vc]; objc_setAssociatedObject(vc, &kPresenting, self, OBJC_ASSOCIATION_ASSIGN); objc_setAssociatedObject(vc, &kKind, [NSNumber numberWithInt: k], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)presentViewControllerAsSheet:(NSViewController *)vc
{
	NSWindow *host = [[self view] window]; if (!host) return;
	NSWindow *w = [self wsdMakeWindowFor: vc style: NSTitledWindowMask];
	[self wsdRegisterPresented: vc kind: KindSheet];
	[vc viewWillAppear];
	/* GNUstep's beginSheet blocks until the sheet is dismissed (a modal session); a presented view controller must return at once, so the window is attached to the host's title bar as a child */
	NSRect hf = [host frame], wf = [w frame]; [w setFrameOrigin: NSMakePoint(NSMidX(hf) - wf.size.width / 2, NSMaxY([host contentRectForFrameRect: hf]) - wf.size.height)];
	[host addChildWindow: w ordered: NSWindowAbove]; [w makeKeyAndOrderFront: nil];
	[vc viewDidAppear];
}
- (void)presentViewControllerAsModalWindow:(NSViewController *)vc
{
	NSWindow *w = [self wsdMakeWindowFor: vc style: NSTitledWindowMask | NSClosableWindowMask];
	[self wsdRegisterPresented: vc kind: KindModal];
	[vc viewWillAppear]; [w center]; [w makeKeyAndOrderFront: nil]; [vc viewDidAppear];
}
- (void)presentViewController:(NSViewController *)vc asPopoverRelativeToRect:(NSRect)r ofView:(NSView *)anchor preferredEdge:(NSRectEdge)edge behavior:(NSInteger)behavior
{
	NSWindow *host = [anchor window]; if (!host) return;
	NSWindow *w = [self wsdMakeWindowFor: vc style: NSBorderlessWindowMask];
	[w setLevel: NSPopUpMenuWindowLevel]; [w setHasShadow: YES];
	NSRect a = [host convertRectToScreen: [anchor convertRect: NSIsEmptyRect(r) ? [anchor bounds] : r toView: nil]], f = [w frame]; NSPoint o;
	switch (edge) { case NSMinXEdge: o = NSMakePoint(a.origin.x - f.size.width - 6, NSMidY(a) - f.size.height / 2); break; case NSMaxXEdge: o = NSMakePoint(NSMaxX(a) + 6, NSMidY(a) - f.size.height / 2); break;
	case NSMaxYEdge: o = NSMakePoint(NSMidX(a) - f.size.width / 2, NSMaxY(a) + 6); break; default: o = NSMakePoint(NSMidX(a) - f.size.width / 2, a.origin.y - f.size.height - 6); }
	[w setFrameOrigin: o]; [self wsdRegisterPresented: vc kind: KindPopover];
	[vc viewWillAppear]; [w orderFront: nil]; [vc viewDidAppear];
	if (behavior == 1 /* transient */) objc_setAssociatedObject(w, &kPop, [NSNumber numberWithBool: YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)presentViewController:(NSViewController *)vc animator:(id)animator
{
	[self wsdRegisterPresented: vc kind: KindAnimator]; objc_setAssociatedObject(vc, &kWin, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(vc, &kPop, animator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[animator animatePresentationOfViewController: vc fromViewController: self];
}
- (void)dismissViewController:(NSViewController *)vc
{
	NSMutableArray *a = objc_getAssociatedObject(self, &kPresented); if (![a containsObject: vc]) return;
	int kind = [objc_getAssociatedObject(vc, &kKind) intValue]; NSWindow *w = objc_getAssociatedObject(vc, &kWin);
	[vc retain]; [vc viewWillDisappear];
	if (kind == KindAnimator) { id an = objc_getAssociatedObject(vc, &kPop); [an animateDismissalOfViewController: vc fromViewController: self]; }
	else if (w) { if (kind == KindSheet) { [[w parentWindow] removeChildWindow: w]; [[[self view] window] makeKeyAndOrderFront: nil]; } [w orderOut: nil]; [w setContentView: nil]; objc_setAssociatedObject(w, &kPresented, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	[a removeObject: vc]; objc_setAssociatedObject(vc, &kPresenting, nil, OBJC_ASSOCIATION_ASSIGN); objc_setAssociatedObject(vc, &kWin, nil, OBJC_ASSOCIATION_ASSIGN);
	[vc viewDidDisappear]; [vc release];
}
- (void)dismissController:(id)sender { NSViewController *p = [self presentingViewController]; if (p) [p dismissViewController: self]; else [[[self view] window] performClose: sender]; }

- (void)transitionFromViewController:(NSViewController *)from toViewController:(NSViewController *)to options:(NSUInteger)opts completionHandler:(void (^)(void))h
{
	NSView *fv = [from view], *sup = [fv superview] ?: [[self view] isKindOfClass: [NSView class]] ? [self view] : nil;
	NSRect fr = [fv frame]; NSView *tv = [to view];
	[to viewWillAppear]; [from viewWillDisappear];
	[tv setFrame: fr]; [tv setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	if (sup) { [sup addSubview: tv positioned: NSWindowAbove relativeTo: fv]; }
	[fv removeFromSuperview];
	[from viewDidDisappear]; [to viewDidAppear];
	if (h) h();
}
@end

/* NSEvent local monitors: every event the application is about to dispatch goes through the handlers whose mask contains its type, the last added first; a handler returns the event
 * (possibly another one) to go on or nil to drop it. (Global monitors would need the window server to send other applications' events: not done.) */
@interface WsdMonitor : NSObject { @public unsigned long long mask; id (^handler)(NSEvent *); } @end
@implementation WsdMonitor - (void)dealloc { [handler release]; [super dealloc]; } @end
static NSMutableArray *monitors; static IMP origSendEvent;
static void wsdSendEvent(NSApplication *self, SEL _cmd, NSEvent *e)
{
	if ([monitors count])
	{
		unsigned long long bit = 1ULL << [e type];
		for (WsdMonitor *m in [[monitors reverseObjectEnumerator] allObjects])
		{
			if (!(m->mask & bit)) continue;
			e = m->handler(e); if (!e) return;
			bit = 1ULL << [e type];
		}
	}
	((void (*)(id, SEL, id))origSendEvent)(self, _cmd, e);
}
@implementation NSEvent (WsdMonitors)
+ (id)addLocalMonitorForEventsMatchingMask:(unsigned long long)mask handler:(NSEvent *(^)(NSEvent *))h
{
	if (!monitors) monitors = [[NSMutableArray alloc] init];
	WsdMonitor *m = [[[WsdMonitor alloc] init] autorelease]; m->mask = mask; m->handler = [h copy]; [monitors addObject: m]; return m;
}
+ (void)removeMonitor:(id)m { [monitors removeObject: m]; }
@end
@interface WsdMonitorInit : NSObject @end
@implementation WsdMonitorInit
+ (void)load { Method m = class_getInstanceMethod([NSApplication class], @selector(sendEvent:)); if (m) { origSendEvent = method_getImplementation(m); class_replaceMethod([NSApplication class], @selector(sendEvent:), (IMP)wsdSendEvent, method_getTypeEncoding(m)); } }
@end

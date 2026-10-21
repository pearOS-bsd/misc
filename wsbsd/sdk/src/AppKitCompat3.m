/* See wsbsd/AppKitCompat3.h. Categories on GNUstep classes; state that has no instance variable to live in is kept with associated objects. */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat3.h>
#import <objc/runtime.h>
#include <sys/xattr.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <ifaddrs.h>
#include <net/if.h>

static id Get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void Set(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static BOOL GetBool(id o, const void *k) { return [Get(o, k) boolValue]; }

@implementation NSProcessInfo (WsbsdVersion)
- (NSOperatingSystemVersion)operatingSystemVersion { return (NSOperatingSystemVersion){ 15, 0, 0 }; }
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)v { NSOperatingSystemVersion c = [self operatingSystemVersion]; return c.majorVersion > v.majorVersion || (c.majorVersion == v.majorVersion && (c.minorVersion > v.minorVersion || (c.minorVersion == v.minorVersion && c.patchVersion >= v.patchVersion))); }
@end

static const char kIdent, kPMItem, kAllowsHidden, kAction, kLBM, kWraps, kTightening, kTBStyle, kTitleUI, kSharedFocus, kFSMin, kColW, kSpellLang, kSpellAuto, kAutoTouch;
@implementation NSView (WsbsdCompat3)
- (NSString *)identifier { return Get(self, &kIdent); }
- (void)setIdentifier:(NSString *)i { Set(self, &kIdent, [i copy]); }
@end
@implementation NSMenuItem (WsbsdCompat3)
- (NSMenuItem *)parentItem { NSMenu *m = [self menu]; NSMenu *sup = [m supermenu]; if (!sup) return nil; for (NSMenuItem *i in [sup itemArray]) if ([i submenu] == m) return i; return nil; }
- (BOOL)allowsKeyEquivalentWhenHidden { return GetBool(self, &kAllowsHidden); }
- (void)setAllowsKeyEquivalentWhenHidden:(BOOL)f { Set(self, &kAllowsHidden, @(f)); }
@end
@implementation NSMenu (WsbsdCompat3)
- (void)cancelTracking { [self close]; }
@end
@implementation NSValue (WsbsdProperties) @end
@implementation NSURL (WsbsdCompat3)
- (NSURL *)filePathURL { return [self isFileURL] ? [NSURL fileURLWithPath: [[self path] stringByStandardizingPath]] : nil; }
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error
{
	if ([key isEqual: NSURLTagNamesKey] && [self isFileURL]) {                                                 /* Finder tags: a property list in the user-tags extended attribute */
		NSData *pl = [NSPropertyListSerialization dataWithPropertyList: value ?: @[] format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL];
		int rc = [value count] ? setxattr([[self path] fileSystemRepresentation], "com.apple.metadata:_kMDItemUserTags", [pl bytes], [pl length], 0, 0) : removexattr([[self path] fileSystemRepresentation], "com.apple.metadata:_kMDItemUserTags", 0);
		if (rc == 0 || errno == ENOATTR) return YES;
	}
	if (error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: @{ NSLocalizedDescriptionKey: @"The resource value could not be set." }]; return NO;
}
- (void)setTemporaryResourceValue:(id)value forKey:(NSString *)key { (void)value; (void)key; }
@end
NSString *const NSURLTagNamesKey = @"NSURLTagNamesKey";
@implementation NSFileManager (WsbsdCompat3)
- (NSURL *)homeDirectoryForCurrentUser { return [NSURL fileURLWithPath: NSHomeDirectory()]; }
- (BOOL)getRelationship:(NSURLRelationship *)out ofDirectory:(NSSearchPathDirectory)dir inDomain:(NSSearchPathDomainMask)mask toItemAtURL:(NSURL *)url error:(NSError **)error
{
	NSString *item = [[url path] stringByStandardizingPath]; *out = NSURLRelationshipOther;
	for (NSString *d in NSSearchPathForDirectoriesInDomains(dir, mask, YES)) {
		NSString *dd = [d stringByStandardizingPath]; if ([item isEqual: dd]) { *out = NSURLRelationshipSame; break; } if ([item hasPrefix: [dd stringByAppendingString: @"/"]]) { *out = NSURLRelationshipContains; break; } }
	(void)error; return YES;
}
- (NSArray *)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray *)keys options:(NSUInteger)options
{
	struct statfs *fs; int n = getmntinfo(&fs, MNT_NOWAIT); NSMutableArray *out = [NSMutableArray array];
	for (int i = 0; i < n; i++) {
		NSString *m = [NSString stringWithUTF8String: fs[i].f_mntonname]; NSString *t = [NSString stringWithUTF8String: fs[i].f_fstypename];
		if ((options & NSVolumeEnumerationSkipHiddenVolumes) && ([@[ @"devfs", @"fdescfs", @"procfs", @"linprocfs", @"linsysfs", @"tmpfs", @"nullfs", @"unionfs" ] containsObject: t] || [m hasPrefix: @"/dev"] || [m hasPrefix: @"/var/"] || [m hasPrefix: @"/compat"])) continue;
		[out addObject: [NSURL fileURLWithPath: m isDirectory: YES]];
	}
	return out;
}
@end
@implementation NSKeyedArchiver (WsbsdCompat3)
- (NSMutableData *)encodedData { [self finishEncoding]; return (NSMutableData *)[[self valueForKey: @"data"] mutableCopy]; }                  /* GNUstep keeps the output in its ivar "_data"; the key path reads it */
@end
@implementation NSBundle (WsbsdCompat3)
- (NSImage *)imageForResource:(NSString *)name { NSString *p = [self pathForImageResource: name]; return p ? [[NSImage alloc] initWithContentsOfFile: p] : nil; }
@end
@implementation NSImage (WsbsdLayers)
- (id)layerContentsForContentsScale:(CGFloat)s { (void)s; CGImageRef r = [self CGImageForProposedRect: NULL context: nil hints: nil]; return (__bridge id)r; }
@end
@implementation NSMutableParagraphStyle (WsbsdCompat3)
- (BOOL)allowsDefaultTighteningForTruncation { return GetBool(self, &kTightening); }
- (void)setAllowsDefaultTighteningForTruncation:(BOOL)f { Set(self, &kTightening, @(f)); }
@end

@implementation NSWindow (WsbsdCompat3)
static BOOL sTabbing = YES;
+ (BOOL)allowsAutomaticWindowTabbing { return sTabbing; }
+ (void)setAllowsAutomaticWindowTabbing:(BOOL)f { sTabbing = f; }
- (NSWindowToolbarStyle)toolbarStyle { return (NSWindowToolbarStyle)[Get(self, &kTBStyle) integerValue]; }
- (void)setToolbarStyle:(NSWindowToolbarStyle)s { Set(self, &kTBStyle, @(s)); }
- (BOOL)isOnActiveSpace { return YES; }
@end
@implementation NSApplication (WsbsdCompat3)
- (BOOL)automaticCustomizeTouchBarMenuItemEnabled { return GetBool(self, &kAutoTouch); }
- (void)setAutomaticCustomizeTouchBarMenuItemEnabled:(BOOL)f { Set(self, &kAutoTouch, @(f)); }
- (BOOL)isFullKeyboardAccessEnabled { return NO; }
@end
@implementation NSWorkspace (WsbsdCompat3)
- (BOOL)isVoiceOverEnabled { return NO; }
@end
NSString *const NSApplicationLaunchUserNotificationKey = @"NSApplicationLaunchUserNotificationKey";
NSString *const NSAnimateBinding = @"animate";
NSString *const NSDocumentEditedBinding = @"documentEdited";
@implementation NSSpellChecker (WsbsdCompat3)
- (NSArray *)availableLanguages { return @[ @"en_US" ]; }
- (BOOL)automaticallyIdentifiesLanguages { return GetBool(self, &kSpellAuto); }
- (void)setAutomaticallyIdentifiesLanguages:(BOOL)f { Set(self, &kSpellAuto, @(f)); }
@end
@implementation NSHelpManager (WsbsdCompat3)
- (void)openHelpAnchor:(NSString *)anchor inBook:(NSString *)book { (void)anchor; (void)book; }                         /* there is no Help Viewer yet */
@end
@implementation NSTitlebarAccessoryViewController (WsbsdCompat3)
- (CGFloat)fullScreenMinHeight { return [Get(self, &kFSMin) doubleValue]; }
- (void)setFullScreenMinHeight:(CGFloat)h { Set(self, &kFSMin, @(h)); }
@end
@implementation NSTableView (WsbsdCompat3)
- (void)enumerateAvailableRowViewsUsingBlock:(void (^)(NSTableRowView *, NSInteger))h
{
	NSRange r = [self rowsInRect: [self visibleRect]]; for (NSUInteger i = r.location; i < NSMaxRange(r); i++) { NSTableRowView *v = [self rowViewAtRow: (NSInteger)i makeIfNecessary: NO]; if (v) h(v, (NSInteger)i); }
}
@end
@implementation NSLayoutConstraint (WsbsdAnimator)
- (instancetype)animator { return self; }                                                                                            /* the constant changes at once */
@end
@implementation NSBrowser (WsbsdCompat3)
- (CGFloat)defaultColumnWidth { id v = Get(self, &kColW); return v ? [v doubleValue] : 200; }
- (void)setDefaultColumnWidth:(CGFloat)w { Set(self, &kColW, @(w)); }
@end
@implementation NSViewController (WsbsdRestoration)
- (void)encodeRestorableStateWithCoder:(NSCoder *)c { (void)c; }
- (void)restoreStateWithCoder:(NSCoder *)c { (void)c; }
@end

/* accessibility: the attribute list is empty and nothing is settable; element links are kept */
@implementation NSObject (WsbsdAccessibility)
- (NSUInteger)accessibilityArrayAttributeCount:(NSString *)a { (void)a; return 0; }
- (NSArray *)accessibilityArrayAttributeValues:(NSString *)a index:(NSUInteger)i maxCount:(NSUInteger)m { (void)a; (void)i; (void)m; return @[]; }
- (NSUInteger)accessibilityIndexOfChild:(id)c { (void)c; return NSNotFound; }
- (NSArray *)accessibilityAttributeNames { return @[]; }
- (BOOL)accessibilityIsAttributeSettable:(NSString *)a { (void)a; return NO; }
- (void)accessibilitySetValue:(id)v forAttribute:(NSString *)a { (void)v; (void)a; }
- (id)accessibilityTitleUIElement { return Get(self, &kTitleUI); }
- (void)setAccessibilityTitleUIElement:(id)e { Set(self, &kTitleUI, e); }
- (NSArray *)accessibilitySharedFocusElements { return Get(self, &kSharedFocus); }
- (void)setAccessibilitySharedFocusElements:(NSArray *)a { Set(self, &kSharedFocus, [a copy]); }
@end

/* touch bar */
NSString *const NSTouchBarItemIdentifierOtherItemsProxy = @"NSTouchBarItemIdentifierOtherItemsProxy";
NSString *const NSTouchBarItemIdentifierFlexibleSpace = @"NSTouchBarItemIdentifierFlexibleSpace";
NSString *const NSTouchBarItemIdentifierFixedSpaceSmall = @"NSTouchBarItemIdentifierFixedSpaceSmall";
NSString *const NSImageNameTouchBarGoBackTemplate = @"NSTouchBarGoBackTemplate";
NSString *const NSImageNameTouchBarGoForwardTemplate = @"NSTouchBarGoForwardTemplate";
static const char kTBDel, kTBDef, kTBAllowed, kTBCust, kTBItemId, kTBView;
@implementation NSTouchBar (WsbsdCompat3)
- (id)delegate { return Get(self, &kTBDel); } - (void)setDelegate:(id)d { objc_setAssociatedObject(self, &kTBDel, d, OBJC_ASSOCIATION_ASSIGN); }
- (NSArray *)defaultItemIdentifiers { return Get(self, &kTBDef); } - (void)setDefaultItemIdentifiers:(NSArray *)a { Set(self, &kTBDef, [a copy]); }
- (NSArray *)customizationAllowedItemIdentifiers { return Get(self, &kTBAllowed); } - (void)setCustomizationAllowedItemIdentifiers:(NSArray *)a { Set(self, &kTBAllowed, [a copy]); }
- (NSString *)customizationIdentifier { return Get(self, &kTBCust); } - (void)setCustomizationIdentifier:(NSString *)s { Set(self, &kTBCust, [s copy]); }
@end
@implementation NSTouchBarItem (WsbsdCompat3)
- (instancetype)initWithIdentifier:(NSString *)i { if ((self = [self init])) Set(self, &kTBItemId, [i copy]); return self; }
- (NSString *)identifier { return Get(self, &kTBItemId); }
@end
static const char kCustLabel, kPriority, kInputCtx, kAnimDest;
@implementation NSCustomTouchBarItem (WsbsdCompat3)
- (NSView *)view { return Get(self, &kTBView); } - (void)setView:(NSView *)v { Set(self, &kTBView, v); }
- (NSString *)customizationLabel { return Get(self, &kCustLabel); } - (void)setCustomizationLabel:(NSString *)l { Set(self, &kCustLabel, [l copy]); }
@end
@implementation NSTouchBarItem (WsbsdPriority)
- (float)visibilityPriority { return [Get(self, &kPriority) floatValue]; } - (void)setVisibilityPriority:(float)p { Set(self, &kPriority, @(p)); }
@end
NSString *const NSImageNameTouchBarSearchTemplate = @"NSTouchBarSearchTemplate";
NSString *const NSImageNameTouchBarBookmarksTemplate = @"NSTouchBarBookmarksTemplate";
NSString *const NSImageNameTouchBarAddTemplate = @"NSTouchBarAddTemplate";
NSString *const NSImageNameTouchBarRefreshTemplate = @"NSTouchBarRefreshTemplate";
NSString *const NSImageNameTouchBarSidebarTemplate = @"NSTouchBarSidebarTemplate";
@implementation NSView (WsbsdInput)
- (NSTextInputContext *)inputContext
{
	if (![self conformsToProtocol: @protocol(NSTextInputClient)]) return nil; NSTextInputContext *c = Get(self, &kInputCtx);
	if (!c) { c = [[NSTextInputContext alloc] initWithClient: (id<NSTextInputClient>)self]; Set(self, &kInputCtx, c); } return c;
}
- (BOOL)isInFullScreenMode { return NO; }
@end
@implementation NSObject (WsbsdDraggingInfo)
- (BOOL)animatesToDestination { return GetBool(self, &kAnimDest); } - (void)setAnimatesToDestination:(BOOL)f { Set(self, &kAnimDest, @(f)); }
- (void)enumerateDraggingItemsWithOptions:(NSUInteger)o forView:(NSView *)v classes:(NSArray *)classes searchOptions:(NSDictionary *)so usingBlock:(void (^)(NSDraggingItem *, NSInteger, BOOL *))block
{
	if (![self respondsToSelector: @selector(draggingPasteboard)]) return; NSPasteboard *pb = [(id)self draggingPasteboard]; NSArray *objs = [pb readObjectsForClasses: classes options: so] ?: @[]; BOOL stop = NO; NSInteger i = 0;
	for (id obj in objs) { NSDraggingItem *it = [[NSDraggingItem alloc] initWithPasteboardWriter: (id)obj]; block(it, i++, &stop); if (stop) break; }
}
@end
@implementation NSSpellChecker (WsbsdLearn)
static NSMutableSet *Learned(void) { static NSMutableSet *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [NSMutableSet setWithArray: [[NSUserDefaults standardUserDefaults] arrayForKey: @"WsbsdLearnedWords"] ?: @[]]; }); return s; }
- (void)learnWord:(NSString *)w { [Learned() addObject: w]; [[NSUserDefaults standardUserDefaults] setObject: [Learned() allObjects] forKey: @"WsbsdLearnedWords"]; }
- (void)unlearnWord:(NSString *)w { [Learned() removeObject: w]; [[NSUserDefaults standardUserDefaults] setObject: [Learned() allObjects] forKey: @"WsbsdLearnedWords"]; }
@end
/* request properties: kept per request object (GNUstep's own store only accepts the first property) */
static const char kReqProps;
@implementation NSURLProtocol (WsbsdProperties)
+ (id)propertyForKey:(NSString *)key inRequest:(NSURLRequest *)request { return [Get(request, &kReqProps) objectForKey: key]; }
+ (void)setProperty:(id)value forKey:(NSString *)key inRequest:(NSMutableURLRequest *)request
{
	NSMutableDictionary *d = Get(request, &kReqProps); if (!d) { d = [NSMutableDictionary dictionary]; Set(request, &kReqProps, d); } if (value) d[key] = value; else [d removeObjectForKey: key];
}
+ (void)removePropertyForKey:(NSString *)key inRequest:(NSMutableURLRequest *)request { [Get(request, &kReqProps) removeObjectForKey: key]; }
@end

@implementation NSDraggingItem { id _item; NSRect _frame; NSArray *_comps; NSArray *(^_provider)(void); }
@synthesize item = _item, draggingFrame = _frame, imageComponentsProvider = _provider;
- (instancetype)initWithPasteboardWriter:(id)w { if ((self = [super init])) _item = w; return self; }
- (NSArray *)imageComponents { return _provider ? _provider() : _comps; }
- (void)setDraggingFrame:(NSRect)f contents:(id)c { _frame = f; NSDraggingImageComponent *ic = [NSDraggingImageComponent draggingImageComponentWithKey: NSDraggingImageComponentIconKey]; [ic setContents: c]; [ic setFrame: NSMakeRect(0, 0, f.size.width, f.size.height)]; _comps = @[ ic ]; }
@end
/* drag sessions: the first item's image and pasteboard writer go through the classic call */
@implementation NSDraggingSession { NSPasteboard *_pb; NSInteger _seq; NSPoint _loc; BOOL _anim; }
@synthesize draggingLocation = _loc, animatesToStartingPositionsOnCancelOrFail = _anim;
- (NSPasteboard *)draggingPasteboard { return _pb; } - (NSInteger)draggingSequenceNumber { return _seq; }
+ (NSDraggingSession *)wsbsdWithPasteboard:(NSPasteboard *)pb { static NSInteger n; NSDraggingSession *s = [NSDraggingSession new]; s->_pb = pb; s->_seq = ++n; return s; }
@end
@interface NSDraggingSession (Wsbsd) + (NSDraggingSession *)wsbsdWithPasteboard:(NSPasteboard *)pb; @end
@implementation NSView (WsbsdDraggingSession)
- (NSDraggingSession *)beginDraggingSessionWithItems:(NSArray *)items event:(NSEvent *)event source:(id)source
{
	NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard]; [pb clearContents]; NSMutableArray *writers = [NSMutableArray array]; NSImage *img = nil; NSRect fr = NSZeroRect;
	for (NSDraggingItem *it in items) { id w = [it item]; if (w) [writers addObject: w]; if (!img) { img = [[[it imageComponents] firstObject] contents]; fr = [it draggingFrame]; } }
	[pb writeObjects: writers];
	NSDraggingSession *s = [NSDraggingSession wsbsdWithPasteboard: pb];
	[self dragImage: img ?: [NSImage imageNamed: NSImageNameMultipleDocuments] at: fr.origin offset: NSZeroSize event: event pasteboard: pb source: source slideBack: YES];
	return s;
}
@end

/* a rounded rectangle path (Opal has no CGPathCreateWithRoundedRect) */
CGPathRef CGPathCreateWithRoundedRect(CGRect r, CGFloat cw, CGFloat ch, const CGAffineTransform *t)
{
	CGMutablePathRef p = CGPathCreateMutable(); cw = MIN(cw, r.size.width / 2); ch = MIN(ch, r.size.height / 2); CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
	CGPathMoveToPoint(p, t, x0 + cw, y0); CGPathAddLineToPoint(p, t, x1 - cw, y0); CGPathAddCurveToPoint(p, t, x1 - cw * 0.4477, y0, x1, y0 + ch * 0.4477, x1, y0 + ch);
	CGPathAddLineToPoint(p, t, x1, y1 - ch); CGPathAddCurveToPoint(p, t, x1, y1 - ch * 0.4477, x1 - cw * 0.4477, y1, x1 - cw, y1);
	CGPathAddLineToPoint(p, t, x0 + cw, y1); CGPathAddCurveToPoint(p, t, x0 + cw * 0.4477, y1, x0, y1 - ch * 0.4477, x0, y1 - ch);
	CGPathAddLineToPoint(p, t, x0, y0 + ch); CGPathAddCurveToPoint(p, t, x0, y0 + ch * 0.4477, x0 + cw * 0.4477, y0, x0 + cw, y0); CGPathCloseSubpath(p); return p;
}

/* ---- the is-getters need no code: the declarations in the header only ---- */
@implementation NSProgress (WsbsdCompat3)
static const char kLD, kLAD;
- (void)setLocalizedDescription:(NSString *)d { Set(self, &kLD, [d copy]); [self setUserInfoObject: d forKey: @"NSProgressLocalizedDescription"]; }
- (void)setLocalizedAdditionalDescription:(NSString *)d { Set(self, &kLAD, [d copy]); }
@end
NSString *const NSProgressKindFile = @"NSProgressKindFile";
NSString *const NSProgressEstimatedTimeRemainingKey = @"NSProgressEstimatedTimeRemainingKey";
NSString *const NSProgressThroughputKey = @"NSProgressThroughputKey";

@implementation NSTask (WsbsdTermination)
static const char kTermH;
- (void (^)(NSTask *))terminationHandler { return Get(self, &kTermH); }
- (void)setTerminationHandler:(void (^)(NSTask *))h
{
	Set(self, &kTermH, [h copy]); if (!h) return;
	__block id token = [[NSNotificationCenter defaultCenter] addObserverForName: NSTaskDidTerminateNotification object: self queue: nil usingBlock: ^(NSNotification *n) {
		[[NSNotificationCenter defaultCenter] removeObserver: token]; void (^hh)(NSTask *) = [(NSTask *)n.object terminationHandler]; if (hh) hh(n.object); }];
}
@end
@implementation NSStackView (WsbsdCompat3)
- (NSArray *)views { return [self respondsToSelector: @selector(arrangedSubviews)] ? [self arrangedSubviews] : [self subviews]; }
@end
@implementation NSGridRow (WsbsdCompat3)
static const char kRowAlign;
- (NSGridRowAlignment)rowAlignment { return (NSGridRowAlignment)[Get(self, &kRowAlign) integerValue]; }
- (void)setRowAlignment:(NSGridRowAlignment)a { Set(self, &kRowAlign, @(a)); }
@end
@implementation NSViewController (WsbsdChildren)
static const char kChildren, kVCIdent, kParent;
- (NSArray<NSViewController *> *)childViewControllers { return [Get(self, &kChildren) copy] ?: @[]; }
- (void)addChildViewController:(NSViewController *)c { NSMutableArray *a = Get(self, &kChildren); if (!a) { a = [NSMutableArray array]; Set(self, &kChildren, a); } [a addObject: c]; objc_setAssociatedObject(c, &kParent, self, OBJC_ASSOCIATION_ASSIGN); }
- (void)removeFromParentViewController { NSViewController *p = objc_getAssociatedObject(self, &kParent); [Get(p, &kChildren) removeObject: self]; objc_setAssociatedObject(self, &kParent, nil, OBJC_ASSOCIATION_ASSIGN); }
- (NSString *)identifier { return Get(self, &kVCIdent); }
- (void)setIdentifier:(NSString *)i { Set(self, &kVCIdent, [i copy]); }
@end
@implementation NSSplitViewItem (WsbsdCompat3)
static void SetIvar(id o, const char *name, const void *src, size_t n) { Ivar iv = class_getInstanceVariable([NSSplitViewItem class], name); if (iv) memcpy((char *)(__bridge void *)o + ivar_getOffset(iv), src, n); }
- (void)setCanCollapse:(BOOL)f { SetIvar(self, "_canCollapse", &f, sizeof f); }
- (void)setHoldingPriority:(float)p { CGFloat v = p; SetIvar(self, "_holdingPriority", &v, sizeof v); }
@end
@implementation NSURL (WsbsdPasteboardWriting)
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pb { (void)pb; return @[ NSURLPboardType, NSStringPboardType ]; }
- (id)pasteboardPropertyListForType:(NSString *)type { return [type isEqual: NSURLPboardType] ? [self absoluteString] : [self isFileURL] ? [self path] : [self absoluteString]; }
@end
@implementation NSView (WsbsdDragSource)
- (void)draggingSession:(NSDraggingSession *)s endedAtPoint:(NSPoint)p operation:(NSDragOperation)op { (void)s; (void)p; (void)op; }
- (void)draggingSession:(NSDraggingSession *)s movedToPoint:(NSPoint)p { (void)s; (void)p; }
@end
@implementation NSSpellChecker (WsbsdCompat4)
- (BOOL)hasLearnedWord:(NSString *)w { (void)w; return NO; }
- (NSArray *)guessesForWordRange:(NSRange)r inString:(NSString *)s language:(NSString *)l inSpellDocumentWithTag:(NSInteger)t { (void)r; (void)s; (void)l; (void)t; return @[]; }
@end

static const char kRotRange, kRotLabel;
@implementation NSAccessibilityCustomRotorItemResult (WsbsdSetters)
- (NSRange)targetRange { return [Get(self, &kRotRange) rangeValue]; } - (void)setTargetRange:(NSRange)r { Set(self, &kRotRange, [NSValue valueWithRange: r]); }
- (NSString *)customLabel { return Get(self, &kRotLabel); } - (void)setCustomLabel:(NSString *)l { Set(self, &kRotLabel, [l copy]); }
@end
@implementation NSAccessibilityCustomRotorSearchParameters
@synthesize currentItem, searchDirection, filterString;
@end
NSString *const NSImageNameTouchBarGoUpTemplate = @"NSTouchBarGoUpTemplate";
NSString *const NSImageNameTouchBarGoDownTemplate = @"NSTouchBarGoDownTemplate";
/* full screen: the window takes the screen's visible frame and gives it back on the second call (no space of its own yet) */
static const char kFullPrev;
@implementation NSWindow (WsbsdFullScreen)
- (void)toggleFullScreen:(id)sender
{
	(void)sender; NSValue *prev = Get(self, &kFullPrev);
	if (prev) { [self setFrame: [prev rectValue] display: YES animate: NO]; Set(self, &kFullPrev, nil); }
	else { Set(self, &kFullPrev, [NSValue valueWithRect: [self frame]]); [self setFrame: [[self screen] frame] display: YES animate: NO]; }
}
@end
@implementation NSAlert (WsbsdLayout)
- (void)layout {}
@end
@implementation NSEvent (WsbsdForce)
- (NSInteger)stage { return 0; }
- (CGFloat)stageTransition { return 0; }
@end
@implementation NSView (WsbsdDefinition)
- (void)showDefinitionForAttributedString:(NSAttributedString *)s atPoint:(NSPoint)p { (void)s; (void)p; }                    /* no dictionary service yet */
@end

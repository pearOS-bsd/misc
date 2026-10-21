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
@implementation NSCustomTouchBarItem (WsbsdCompat3)
- (NSView *)view { return Get(self, &kTBView); } - (void)setView:(NSView *)v { Set(self, &kTBView, v); }
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

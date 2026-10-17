/* Implementations of the methods declared in include/wsbsd/AppKitCompat.h. */
#import <wsbsd/AppKitCompat.h>
#import <objc/runtime.h>

__attribute__((weak)) const CGRect CGRectZero = { { 0, 0 }, { 0, 0 } };
__attribute__((weak)) const CGSize CGSizeZero = { 0, 0 };
__attribute__((weak)) const CGPoint CGPointZero = { 0, 0 };
__attribute__((weak)) const CGRect CGRectNull = { { INFINITY, INFINITY }, { 0, 0 } };
__attribute__((weak)) const CGAffineTransform CGAffineTransformIdentity = { 1, 0, 0, 1, 0, 0 };

static id getAssoc(id o, const void *key) { return objc_getAssociatedObject(o, key); }
static void setAssoc(id o, const void *key, id v) { objc_setAssociatedObject(o, key, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@implementation NSTextView (WsbsdCompat)
- (void)insertText:(id)string replacementRange:(NSRange)range
{
	if (range.location == NSNotFound) { [self insertText: string]; return; }
	NSString *plain = [string isKindOfClass: [NSAttributedString class]] ? [(NSAttributedString *)string string] : string;
	if ([self shouldChangeTextInRange: range replacementString: plain]) {
		if ([string isKindOfClass: [NSAttributedString class]]) [[self textStorage] replaceCharactersInRange: range withAttributedString: string];
		else [[self textStorage] replaceCharactersInRange: range withString: plain];
		[self didChangeText];
	}
}
static const char quoteKey;
- (BOOL)isAutomaticQuoteSubstitutionEnabled { NSNumber *n = getAssoc(self, &quoteKey); return n ? [n boolValue] : YES; }
- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)flag { setAssoc(self, &quoteKey, [NSNumber numberWithBool: flag]); }
@end

@implementation NSButton (WsbsdCompat)
static const char scalingKey;
- (NSImageScaling)imageScaling { NSNumber *n = getAssoc(self, &scalingKey); return n ? (NSImageScaling)[n intValue] : NSImageScaleProportionallyDown; }
- (void)setImageScaling:(NSImageScaling)s { setAssoc(self, &scalingKey, [NSNumber numberWithInt: (int)s]); }
@end

@implementation NSSegmentedControl (WsbsdCompat)
static const char tipsKey, scalesKey;
- (void)setToolTip:(NSString *)tip forSegment:(NSInteger)segment
{
	NSMutableDictionary *d = getAssoc(self, &tipsKey); if (!d) { d = [NSMutableDictionary dictionary]; setAssoc(self, &tipsKey, d); }
	if (tip) [d setObject: tip forKey: [NSNumber numberWithInteger: segment]]; else [d removeObjectForKey: [NSNumber numberWithInteger: segment]];
}
- (NSString *)toolTipForSegment:(NSInteger)segment { return [(NSDictionary *)getAssoc(self, &tipsKey) objectForKey: [NSNumber numberWithInteger: segment]]; }
- (void)setImageScaling:(NSImageScaling)s forSegment:(NSInteger)segment
{
	NSMutableDictionary *d = getAssoc(self, &scalesKey); if (!d) { d = [NSMutableDictionary dictionary]; setAssoc(self, &scalesKey, d); }
	[d setObject: [NSNumber numberWithInt: (int)s] forKey: [NSNumber numberWithInteger: segment]];
}
- (NSImageScaling)imageScalingForSegment:(NSInteger)segment { NSNumber *n = [(NSDictionary *)getAssoc(self, &scalesKey) objectForKey: [NSNumber numberWithInteger: segment]]; return n ? (NSImageScaling)[n intValue] : NSImageScaleProportionallyDown; }
@end

@implementation NSDocument (WsbsdCompat)
static const char draftKey;
- (BOOL)isDraft { return [(NSNumber *)getAssoc(self, &draftKey) boolValue]; }
- (void)setDraft:(BOOL)flag { setAssoc(self, &draftKey, [NSNumber numberWithBool: flag]); }
@end

@implementation NSPasteboard (WsbsdCompat)
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray *)types { return [self availableTypeFromArray: types] != nil; }
@end

@implementation NSAlert (WsbsdCompat)
static const char accessoryKey;
- (NSView *)accessoryView { return getAssoc(self, &accessoryKey); }
- (void)setAccessoryView:(NSView *)v { setAssoc(self, &accessoryKey, v); }
@end

@implementation NSColor (WsbsdCompat)
+ (NSColor *)linkColor { return [NSColor colorWithCalibratedRed: 0.0 green: 0.4 blue: 0.8 alpha: 1.0]; }
+ (NSColor *)separatorColor { return [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.1]; }
@end

@implementation NSAttributedString (WsbsdCompat)
- (void)enumerateAttributesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary *, NSRange, BOOL *))block
{
	NSUInteger end = NSMaxRange(range), i = range.location; BOOL stop = NO;
	NSMutableArray *runs = [NSMutableArray array];
	while (i < end) {
		NSRange r; NSDictionary *a = [self attributesAtIndex: i effectiveRange: &r];
		NSRange c = NSIntersectionRange(r, range); if (c.length == 0) break;
		[runs addObject: [NSArray arrayWithObjects: a ? a : [NSDictionary dictionary], [NSValue valueWithRange: c], nil]];
		i = NSMaxRange(c);
	}
	BOOL rev = (opts & NSAttributedStringEnumerationReverse) != 0;
	NSEnumerator *e = rev ? [runs reverseObjectEnumerator] : [runs objectEnumerator]; NSArray *run;
	while (!stop && (run = [e nextObject])) block([run objectAtIndex: 0], [[run objectAtIndex: 1] rangeValue], &stop);
}
- (void)enumerateAttribute:(NSString *)name inRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id, NSRange, BOOL *))block
{
	NSUInteger end = NSMaxRange(range), i = range.location; BOOL stop = NO;
	NSMutableArray *runs = [NSMutableArray array];
	while (i < end) {
		NSRange r; id v = [self attribute: name atIndex: i longestEffectiveRange: &r inRange: range];
		if (r.length == 0) break;
		[runs addObject: [NSArray arrayWithObjects: v ? v : [NSNull null], [NSValue valueWithRange: r], nil]];
		i = NSMaxRange(r);
	}
	BOOL rev = (opts & NSAttributedStringEnumerationReverse) != 0;
	NSEnumerator *e = rev ? [runs reverseObjectEnumerator] : [runs objectEnumerator]; NSArray *run;
	while (!stop && (run = [e nextObject])) { id v = [run objectAtIndex: 0]; block(v == [NSNull null] ? nil : v, [[run objectAtIndex: 1] rangeValue], &stop); }
}
@end

@implementation NSData (WsbsdCompat)
+ (id)dataWithContentsOfFile:(NSString *)path options:(NSUInteger)options error:(NSError **)error
{
	NSData *d = [NSData dataWithContentsOfFile: path];
	if (!d && error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 260 userInfo: [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey]];
	return d;
}
- (NSString *)base64Encoding { return [self base64EncodedStringWithOptions: 0]; }
@end

@implementation NSUndoManager (WsbsdCompat)
- (void)setActionIsDiscardable:(BOOL)flag { (void)flag; }
@end
@implementation NSEvent (WsbsdCompat)
- (BOOL)hasPreciseScrollingDeltas { return NO; }
- (CGFloat)scrollingDeltaX { return [self deltaX]; }
- (CGFloat)scrollingDeltaY { return [self deltaY]; }
@end
@implementation NSControl (WsbsdCompat)
- (NSControlSize)controlSize { return [[self cell] controlSize]; }
- (void)setControlSize:(NSControlSize)size { [[self cell] setControlSize: size]; }
@end
@implementation NSScroller (WsbsdCompat)
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)size scrollerStyle:(int)style { (void)style; return [NSScroller scrollerWidth]; }
@end
@implementation NSColor (WsbsdCompatRows)
+ (NSArray *)alternatingContentBackgroundColors { return [NSArray arrayWithObjects: [NSColor whiteColor], [NSColor colorWithCalibratedWhite: 0.96 alpha: 1.0], nil]; }
@end

@implementation NSView (WsbsdCompat)
static const char clipsKey;
- (BOOL)clipsToBounds { NSNumber *n = getAssoc(self, &clipsKey); return n ? [n boolValue] : NO; }
- (void)setClipsToBounds:(BOOL)flag { setAssoc(self, &clipsKey, [NSNumber numberWithBool: flag]); }
- (NSMenuItem *)enclosingMenuItem { return nil; }
@end
@implementation NSImage (WsbsdCompat)
- (void)lockFocusFlipped:(BOOL)flipped { [self setFlipped: flipped]; [self lockFocus]; }
@end
@implementation NSColor (WsbsdCompatText)
+ (NSColor *)textInsertionPointColor { return [NSColor controlTextColor]; }
+ (NSColor *)unemphasizedSelectedTextBackgroundColor { return [NSColor colorWithCalibratedWhite: 0.83 alpha: 1.0]; }
@end

/* ---- libc / system functions of Darwin that sources call ---- */
#include <string.h>
void memset_pattern4(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 4]; }
void memset_pattern8(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 8]; }
void memset_pattern16(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 16]; }
void OSMemoryBarrier(void) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }

/* ---- AppKit image names newer than GNUstep ---- */
NSString *const NSImageNameStopProgressTemplate = @"NSStopProgressTemplate";
NSString *const NSImageNameRefreshTemplate = @"NSRefreshTemplate";
NSString *const NSImageNameGoLeftTemplate = @"NSGoLeftTemplate";
NSString *const NSImageNameGoRightTemplate = @"NSGoRightTemplate";
NSString *const NSImageNameAddTemplate = @"NSAddTemplate";
NSString *const NSImageNameRemoveTemplate = @"NSRemoveTemplate";

NSString *const NSPasteboardURLReadingFileURLsOnlyKey = @"NSPasteboardURLReadingFileURLsOnlyKey";
NSString *const NSPasteboardURLReadingContentsConformToTypesKey = @"NSPasteboardURLReadingContentsConformToTypesKey";

@implementation NSString (WsbsdCompat)
- (BOOL)localizedCaseInsensitiveContainsString:(NSString *)other { return [self rangeOfString: other options: NSCaseInsensitiveSearch].location != NSNotFound; }
- (BOOL)getBytes:(void *)buffer maxLength:(NSUInteger)max usedLength:(NSUInteger *)used encoding:(NSStringEncoding)enc options:(NSUInteger)opts range:(NSRange)range remainingRange:(NSRangePointer)leftover
{
	NSUInteger usedBytes = 0, i = range.location, end = NSMaxRange(range);
	BOOL lossy = (opts & 1) != 0;                                                   /* NSStringEncodingConversionAllowLossy */
	while (i < end) {
		NSRange r = [self rangeOfComposedCharacterSequenceAtIndex: i]; if (NSMaxRange(r) > end) r.length = end - r.location;
		NSData *d = [[self substringWithRange: r] dataUsingEncoding: enc allowLossyConversion: lossy];
		if (!d) { if (used) *used = usedBytes; if (leftover) *leftover = NSMakeRange(i, end - i); return NO; }
		if (usedBytes + [d length] > max) break;
		if (buffer) memcpy((char *)buffer + usedBytes, [d bytes], [d length]);
		usedBytes += [d length]; i = NSMaxRange(r);
	}
	if (used) *used = usedBytes;
	if (leftover) *leftover = NSMakeRange(i, end - i);
	return YES;
}
@end
@implementation NSWindow (WsbsdCompat)
- (void)setAutorecalculatesContentBorderThickness:(BOOL)flag forEdge:(NSRectEdge)edge { (void)flag; (void)edge; }
- (NSArray *)tabbedWindows { return nil; }
@end
@implementation NSDocument (WsbsdViewing)
- (BOOL)isInViewingMode { return NO; }
@end
@implementation NSFileCoordinator (WsbsdCompat)
- (instancetype)initWithFilePresenter:(id)presenter { (void)presenter; return [self init]; }
@end
@implementation NSPasteboard (WsbsdReading)
- (NSArray *)readObjectsForClasses:(NSArray *)classes options:(NSDictionary *)options
{
	NSMutableArray *out = [NSMutableArray array];
	for (Class c in classes) {
		if (c == [NSURL class]) {
			id files = [self propertyListForType: NSFilenamesPboardType];
			for (NSString *f in ([files isKindOfClass: [NSArray class]] ? files : @[])) [out addObject: [NSURL fileURLWithPath: f]];
		} else if (c == [NSString class]) { NSString *s = [self stringForType: NSStringPboardType]; if (s) [out addObject: s]; }
	}
	(void)options;
	return out;
}
@end
@implementation NSView (WsbsdBacking)
- (NSRect)convertRectFromBacking:(NSRect)r { return r; }
- (NSRect)convertRectToBacking:(NSRect)r { return r; }
- (NSSize)convertSizeFromBacking:(NSSize)s { return s; }
- (NSSize)convertSizeToBacking:(NSSize)s { return s; }
@end
@implementation NSMachPort
+ (NSPort *)portWithMachPort:(uint32_t)p { return [[self alloc] initWithMachPort: p options: 0]; }
- (instancetype)initWithMachPort:(uint32_t)p options:(NSUInteger)f { (void)p; (void)f; return [super init]; }
- (uint32_t)machPort { return 0; }
@end
@implementation NSMachBootstrapServer
+ (instancetype)sharedInstance { static NSMachBootstrapServer *s; if (!s) s = [[self alloc] init]; return s; }
- (NSPort *)portForName:(NSString *)name { (void)name; return nil; }
- (NSPort *)portForName:(NSString *)name host:(NSString *)host { (void)name; (void)host; return nil; }
@end

/* ---- gesture recognizers: GNUstep has the class names only; clicks are recognized in -[NSWindow sendEvent:] ---- */
static void installGestureHook(void);
static const char gTarget, gAction, gEnabled, gView, gState, gDelegate, gButtons, gClicks, gRecognizers;

@implementation NSGestureRecognizer (WsbsdCompat)
- (instancetype)initWithTarget:(id)t action:(SEL)a { self = [self init]; if (self) { [self setTarget: t]; [self setAction: a]; } return self; }
- (id)target { return [(NSValue *)getAssoc(self, &gTarget) nonretainedObjectValue]; }
- (void)setTarget:(id)t { setAssoc(self, &gTarget, t ? [NSValue valueWithNonretainedObject: t] : nil); }
- (SEL)action { NSValue *v = getAssoc(self, &gAction); return v ? (SEL)[v pointerValue] : NULL; }
- (void)setAction:(SEL)a { setAssoc(self, &gAction, [NSValue valueWithPointer: a]); }
- (BOOL)isEnabled { NSNumber *n = getAssoc(self, &gEnabled); return n ? [n boolValue] : YES; }
- (void)setEnabled:(BOOL)f { setAssoc(self, &gEnabled, [NSNumber numberWithBool: f]); }
- (NSView *)view { return [(NSValue *)getAssoc(self, &gView) nonretainedObjectValue]; }
- (void)setView:(NSView *)v { setAssoc(self, &gView, v ? [NSValue valueWithNonretainedObject: v] : nil); }
- (NSInteger)state { return [(NSNumber *)getAssoc(self, &gState) integerValue]; }
- (void)setState:(NSInteger)s { setAssoc(self, &gState, [NSNumber numberWithInteger: s]); }
- (id)delegate { return [(NSValue *)getAssoc(self, &gDelegate) nonretainedObjectValue]; }
- (void)setDelegate:(id)d { setAssoc(self, &gDelegate, d ? [NSValue valueWithNonretainedObject: d] : nil); }
@end
@implementation NSClickGestureRecognizer (WsbsdCompat)
- (NSUInteger)buttonMask { NSNumber *n = getAssoc(self, &gButtons); return n ? [n unsignedIntegerValue] : 1; }
- (void)setButtonMask:(NSUInteger)m { setAssoc(self, &gButtons, [NSNumber numberWithUnsignedInteger: m]); }
- (NSInteger)numberOfClicksRequired { NSNumber *n = getAssoc(self, &gClicks); return n ? [n integerValue] : 1; }
- (void)setNumberOfClicksRequired:(NSInteger)n { setAssoc(self, &gClicks, [NSNumber numberWithInteger: n]); }
@end
@implementation NSView (WsbsdGestures)
- (void)addGestureRecognizer:(NSGestureRecognizer *)r
{
	NSMutableArray *a = getAssoc(self, &gRecognizers); if (!a) { a = [NSMutableArray array]; setAssoc(self, &gRecognizers, a); }
	if (![a containsObject: r]) { [a addObject: r]; [r setView: self]; installGestureHook(); }
}
- (void)removeGestureRecognizer:(NSGestureRecognizer *)r { [(NSMutableArray *)getAssoc(self, &gRecognizers) removeObject: r]; [r setView: nil]; }
- (NSArray *)gestureRecognizers { NSArray *a = getAssoc(self, &gRecognizers); return a ? [a copy] : @[]; }
@end

static IMP origSendEvent;
static void wsbsdSendEvent(id self, SEL _cmd, NSEvent *e)
{
	if ([e type] == NSLeftMouseUp) {
		NSView *hit = [[self contentView] hitTest: [[[self contentView] superview] convertPoint: [e locationInWindow] fromView: nil]];
		for (NSView *v = hit; v; v = [v superview])
			for (NSGestureRecognizer *r in [v gestureRecognizers])
				if ([r isKindOfClass: [NSClickGestureRecognizer class]] && [r isEnabled] && [e clickCount] >= [(NSClickGestureRecognizer *)r numberOfClicksRequired] && [r target] && [r action])
					[[r target] performSelector: [r action] withObject: r];
	}
	((void (*)(id, SEL, NSEvent *))origSendEvent)(self, _cmd, e);
}
static void installGestureHook(void)          /* lazily, at the first recognizer: +load would run before main() and initialize AppKit too early */
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		Method m = class_getInstanceMethod([NSWindow class], @selector(sendEvent:));
		if (m && !origSendEvent) origSendEvent = method_setImplementation(m, (IMP)wsbsdSendEvent);
	});
}

/* ---- smaller AppKit / Foundation gaps ---- */
@implementation NSWindow (WsbsdProperties)
- (BOOL)documentEdited { return [self isDocumentEdited]; }
- (void)setContentBorderThickness:(CGFloat)t forEdge:(NSRectEdge)e { (void)t; (void)e; }
@end
@implementation NSMenuItem (WsbsdHidden)
static const char hiddenKey;
- (BOOL)isHidden { return [(NSNumber *)getAssoc(self, &hiddenKey) boolValue]; }
- (void)setHidden:(BOOL)f { setAssoc(self, &hiddenKey, [NSNumber numberWithBool: f]); }
@end
@implementation NSBundle (WsbsdURLs)
- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)sub
{
	NSMutableArray *urls = [NSMutableArray array];
	for (NSString *p in [self pathsForResourcesOfType: ext inDirectory: sub]) [urls addObject: [NSURL fileURLWithPath: p]];
	return urls;
}
@end
@implementation NSTableView (WsbsdStyle)
static const char styleKey;
- (NSInteger)style { return [(NSNumber *)getAssoc(self, &styleKey) integerValue]; }
- (void)setStyle:(NSInteger)s { setAssoc(self, &styleKey, [NSNumber numberWithInteger: s]); }
@end

@implementation NSOpenPanel (WsbsdCompat)
static const char disclosedKey;
- (BOOL)accessoryViewDisclosed { return [(NSNumber *)getAssoc(self, &disclosedKey) boolValue]; }
- (void)setAccessoryViewDisclosed:(BOOL)f { setAssoc(self, &disclosedKey, [NSNumber numberWithBool: f]); }
@end
@implementation NSWindow (WsbsdURL)
static const char repURLKey;
- (NSURL *)representedURL { return getAssoc(self, &repURLKey); }
- (void)setRepresentedURL:(NSURL *)u { setAssoc(self, &repURLKey, u); if ([u isFileURL]) [self setRepresentedFilename: [u path]]; else [self setRepresentedFilename: @""]; }
@end
@implementation NSPasteboard (WsbsdWriting)
- (NSInteger)clearContents { return [self declareTypes: @[] owner: nil]; }
- (BOOL)writeObjects:(NSArray *)objects
{
	NSMutableArray *files = [NSMutableArray array]; NSString *text = nil;
	for (id o in objects) {
		if ([o isKindOfClass: [NSURL class]] && [o isFileURL]) [files addObject: [o path]];
		else if ([o isKindOfClass: [NSString class]]) text = o;
	}
	NSMutableArray *types = [NSMutableArray array];
	if (text) [types addObject: NSStringPboardType];
	if ([files count]) [types addObject: NSFilenamesPboardType];
	[self addTypes: types owner: nil];
	BOOL ok = YES;
	if (text) ok = [self setString: text forType: NSStringPboardType] && ok;
	if ([files count]) ok = [self setPropertyList: files forType: NSFilenamesPboardType] && ok;
	return ok;
}
@end
NSPasteboardType const NSPasteboardTypeFileURL = @"public.file-url";
@implementation NSScrollView (WsbsdScrolling)
static const char predominantKey;
- (BOOL)usesPredominantAxisScrolling { NSNumber *n = getAssoc(self, &predominantKey); return n ? [n boolValue] : YES; }
- (void)setUsesPredominantAxisScrolling:(BOOL)f { setAssoc(self, &predominantKey, [NSNumber numberWithBool: f]); }
@end
NSString *const NSAppleScriptErrorNumber = @"NSAppleScriptErrorNumber";
NSString *const NSAppleScriptErrorMessage = @"NSAppleScriptErrorMessage";
@implementation NSAppleScript (WsbsdCompat)
- (instancetype)initWithSource:(NSString *)source { (void)source; return [self init]; }
- (id)executeAndReturnError:(NSDictionary **)errorInfo
{
	if (errorInfo) *errorInfo = @{ NSAppleScriptErrorNumber: @(-1708), NSAppleScriptErrorMessage: @"AppleScript is not available on this system" };
	return nil;
}
@end

/* ---- Sparkle: no update framework here. SUUpdater is what a nib may instantiate; like the App Store build of Hex Fiend it hides "Check for Updates" ---- */
@interface SUUpdater : NSObject
@property (nonatomic) BOOL automaticallyChecksForUpdates;
@property (nonatomic) BOOL automaticallyDownloadsUpdates;
@property (nonatomic) NSTimeInterval updateCheckInterval;
@property (nonatomic, strong) NSURL *feedURL;
- (IBAction)checkForUpdates:(id)sender;
- (void)checkForUpdatesInBackground;
@end
@implementation SUUpdater
- (IBAction)checkForUpdates:(id)sender { (void)sender; }
- (void)checkForUpdatesInBackground { }
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if ([item action] == @selector(checkForUpdates:)) { [item setHidden: YES]; return NO; }
	return YES;
}
@end

/* ---- fonts: names of the Mac system fonts map to the faces installed here; +load may not message AppKit classes (main() has not run), so only the runtime API is used ---- */
static IMP origFontWithName;
static NSString *aliasForFont(NSString *name)
{
	NSString *n = [name lowercaseString];
	BOOL bold = [n rangeOfString: @"bold"].location != NSNotFound, ital = [n rangeOfString: @"italic"].location != NSNotFound || [n rangeOfString: @"oblique"].location != NSNotFound;
	if ([n rangeOfString: @"monaco"].location != NSNotFound || [n rangeOfString: @"menlo"].location != NSNotFound || [n rangeOfString: @"courier"].location != NSNotFound ||
	    [n rangeOfString: @"andale"].location != NSNotFound || [n rangeOfString: @"sfmono"].location != NSNotFound || [n rangeOfString: @"sf mono"].location != NSNotFound ||
	    [n rangeOfString: @"consolas"].location != NSNotFound || [n rangeOfString: @"fixed"].location != NSNotFound)
		return bold ? (ital ? @"DejaVuSansMono-BoldOblique" : @"DejaVuSansMono-Bold") : (ital ? @"DejaVuSansMono-Oblique" : @"DejaVuSansMono");
	if ([n rangeOfString: @"times"].location != NSNotFound || [n rangeOfString: @"georgia"].location != NSNotFound || [n rangeOfString: @"palatino"].location != NSNotFound)
		return bold ? @"DejaVuSerif-Bold" : @"DejaVuSerif";
	if ([n rangeOfString: @"helvetica"].location != NSNotFound || [n rangeOfString: @"lucida"].location != NSNotFound || [n rangeOfString: @"arial"].location != NSNotFound ||
	    [n rangeOfString: @"sf pro"].location != NSNotFound || [n rangeOfString: @"sfpro"].location != NSNotFound || [n rangeOfString: @"system"].location != NSNotFound)
		return bold ? @"Inter-Bold" : @"Inter-Regular";
	return nil;
}
static id aliasFontWithName(id self, SEL _cmd, NSString *name, CGFloat size)
{
	id f = ((id (*)(id, SEL, NSString *, CGFloat))origFontWithName)(self, _cmd, name, size);
	if (f || !name) return f;
	NSString *alias = aliasForFont(name);
	return alias ? ((id (*)(id, SEL, NSString *, CGFloat))origFontWithName)(self, _cmd, alias, size) : nil;
}
@interface WsbsdFontAliases : NSObject @end
@implementation WsbsdFontAliases
+ (void)load
{
	Class c = objc_getClass("NSFont");
	Method m = c ? class_getClassMethod(c, sel_registerName("fontWithName:size:")) : NULL;
	if (m && !origFontWithName) origFontWithName = method_setImplementation(m, (IMP)aliasFontWithName);
}
@end

/* ---- NSFont <-> CTFont: on Apple an NSFont IS a CTFont (toll-free); with Opal a CTFontRef is an OPFont and its functions message OPFont methods. Each class forwards the selectors
 * it does not know to an equivalent object of the other one, so a font can be handed to either API. Installed with the runtime API only (+load runs before main). ---- */
#include <CoreText/CoreText.h>
static const char opOfNSKey, nsOfOPKey;
static id forwardNSFont(id self, SEL _cmd, SEL sel)
{
	id op = objc_getAssociatedObject(self, &opOfNSKey);
	if (!op) {
		NSString *name = [(NSFont *)self fontName]; if (!name) return nil;
		op = (__bridge_transfer id)CTFontCreateWithName((__bridge CFStringRef)name, [(NSFont *)self pointSize], NULL);
		if (!op) return nil;
		objc_setAssociatedObject(self, &opOfNSKey, op, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return [op respondsToSelector: sel] ? op : nil;
}
static id forwardOPFont(id self, SEL _cmd, SEL sel)
{
	id ns = objc_getAssociatedObject(self, &nsOfOPKey);
	if (!ns) {
		CTFontRef ct = (__bridge CTFontRef)self;
		NSString *name = (__bridge_transfer NSString *)CTFontCopyPostScriptName(ct);
		ns = name ? [NSFont fontWithName: name size: CTFontGetSize(ct)] : nil;
		if (!ns) return nil;
		objc_setAssociatedObject(self, &nsOfOPKey, ns, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return [ns respondsToSelector: sel] ? ns : nil;
}
@interface WsbsdFontBridge : NSObject @end
@implementation WsbsdFontBridge
+ (void)load
{
	SEL fwd = sel_registerName("forwardingTargetForSelector:");
	Class nsfont = objc_getClass("NSFont"), opfont = objc_getClass("OPFont");
	if (nsfont) class_addMethod(nsfont, fwd, (IMP)forwardNSFont, "@@::");
	if (opfont) class_addMethod(opfont, fwd, (IMP)forwardOPFont, "@@::");
}
@end

/* ---- NSDocument + xib: GNUstep's NSDocument keeps the window of its nib in _window as an assigned pointer and hands it to the window controller with an autorelease, counting on the
 * nib loader's retain. The xib loader does not leave one behind, so the window was released with the loader's connections right after it was created (the document window
 * appeared and vanished). One retain more at the hand-over keeps it; the window is released when its controller closes it. Runtime API only (+load runs before main). ---- */
extern id objc_retain(id);                                         /* the runtime's retain: ARC code may not message -retain */
static IMP origTransferWindow;
static id wsbsdTransferWindowOwnership(id self, SEL _cmd)
{
	id w = ((id (*)(id, SEL))origTransferWindow)(self, _cmd);      /* autoreleased, _window cleared */
	if (w) objc_retain(w);                                         /* the retain the xib loader does not leave: it outlives the loader's connections */
	return w;
}
@interface WsbsdDocumentFix : NSObject @end
@implementation WsbsdDocumentFix
+ (void)load
{
	Class c = objc_getClass("NSDocument");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("_transferWindowOwnership")) : NULL;
	if (m && !origTransferWindow) origTransferWindow = method_setImplementation(m, (IMP)wsbsdTransferWindowOwnership);
}
@end

/* Implementations of the methods declared in include/wsbsd/AppKitCompat.h. */
#import <wsbsd/AppKitCompat.h>
#import <objc/runtime.h>
#import <objc/message.h>

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
+ (NSArray *)alternatingContentBackgroundColors { return [NSColor controlAlternatingRowBackgroundColors]; }      /* the theme's row colours (dark or light) */
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
#include <dlfcn.h>
void memset_pattern4(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 4]; }
void memset_pattern8(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 8]; }
void memset_pattern16(void *b, const void *p, size_t len) { for (size_t i = 0; i < len; i++) ((unsigned char *)b)[i] = ((const unsigned char *)p)[i % 16]; }
void OSMemoryBarrier(void) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }

/* ---- AppKit image names newer than GNUstep ---- */
NSString *const NSImageNameStopProgressTemplate = @"NSStopProgressTemplate";
NSString *const NSImageNameRefreshTemplate = @"NSRefreshTemplate";
NSString *const NSImageNameActionTemplate = @"NSActionTemplate", *const NSImageNameFolder = @"NSFolder", *const NSImageNameSmartBadgeTemplate = @"NSSmartBadgeTemplate";
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
static const char winAppearanceKey, winTransparentKey, winTitleVisKey;
- (id)appearance { return getAssoc(self, &winAppearanceKey); }
- (void)setAppearance:(id)a { setAssoc(self, &winAppearanceKey, a); }
- (BOOL)titlebarAppearsTransparent { return [(NSNumber *)getAssoc(self, &winTransparentKey) boolValue]; }
- (void)setTitlebarAppearsTransparent:(BOOL)f { setAssoc(self, &winTransparentKey, [NSNumber numberWithBool: f]); }
- (NSInteger)titleVisibility { return [(NSNumber *)getAssoc(self, &winTitleVisKey) integerValue]; }
- (void)setTitleVisibility:(NSInteger)v { setAssoc(self, &winTitleVisKey, [NSNumber numberWithInteger: v]); }
- (void)setStyleMask:(NSUInteger)mask
{
	Ivar iv = class_getInstanceVariable([NSWindow class], "_styleMask");
	if (iv) *(NSUInteger *)((char *)(__bridge void *)self + ivar_getOffset(iv)) = mask;
}
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
NSPasteboardType const NSPasteboardTypeURL = @"public.url";
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

/* ---- NSView -setFrame: on Apple is built from -setFrameOrigin: and -setFrameSize:, and applications that track their size override -setFrameSize: (Hex Fiend lays out its
 * bytes per line and displayed lines there). GNUstep's -setFrame: sets the frame itself and never calls it. For a class that overrides -setFrameSize: the same split is done here.
 * Runtime API only (+load runs before main). ---- */
static IMP origViewSetFrame, viewSetFrameSize;
/* the class (from self's up) that implements -setFrameSize: and whether it comes from GNUstep itself: its own views (NSTableView, NSClipView ...) are written for -setFrame: not calling -setFrameSize: and
 * loop when it does; only a -setFrameSize: of the application's (or its libraries') is called */
static BOOL setFrameSizeIsApplications(id self)
{
	SEL sfs = sel_registerName("setFrameSize:");
	for (Class k = object_getClass(self); k; k = class_getSuperclass(k)) {
		unsigned n = 0; Method *ms = class_copyMethodList(k, &n); IMP imp = NULL;
		for (unsigned i = 0; i < n; i++) if (sel_isEqual(method_getName(ms[i]), sfs)) { imp = method_getImplementation(ms[i]); break; }
		free(ms);
		if (imp) {
			Dl_info di; const char *img = dladdr((void *)imp, &di) ? di.dli_fname : NULL;
			return !(img && (strstr(img, "libgnustep-gui") || strstr(img, "libgnustep-back")));
		}
	}
	return NO;
}
static void wsbsdViewSetFrame(id self, SEL _cmd, NSRect f)
{
	SEL sfs = sel_registerName("setFrameSize:");
	if (!setFrameSizeIsApplications(self)) { ((void (*)(id, SEL, NSRect))origViewSetFrame)(self, _cmd, f); return; }
	NSRect old = ((NSRect (*)(id, SEL))objc_msgSend)(self, sel_registerName("frame"));
	if (old.origin.x != f.origin.x || old.origin.y != f.origin.y) ((void (*)(id, SEL, NSPoint))objc_msgSend)(self, sel_registerName("setFrameOrigin:"), f.origin);
	if (old.size.width != f.size.width || old.size.height != f.size.height) ((void (*)(id, SEL, NSSize))objc_msgSend)(self, sfs, f.size);
}
@interface WsbsdViewFrameFix : NSObject @end
@implementation WsbsdViewFrameFix
+ (void)load
{
	Class c = objc_getClass("NSView");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("setFrame:")) : NULL;
	Method s = c ? class_getInstanceMethod(c, sel_registerName("setFrameSize:")) : NULL;
	if (m && s && !origViewSetFrame) { viewSetFrameSize = method_getImplementation(s); origViewSetFrame = method_setImplementation(m, (IMP)wsbsdViewSetFrame); }
}
@end

/* ---- modern property spellings over GNUstep's methods; recents and the alert's suppression button ---- */
@implementation NSString (WsbsdProperties)
@end
@implementation NSToolbar (WsbsdProperties)
@end
@implementation NSScanner (WsbsdProperties)
@end
@implementation NSWindow (WsbsdVisible)
@end
@implementation NSDocumentController (WsbsdRecents)
- (NSArray *)recentDocumentURLs
{
	NSMutableArray *urls = [NSMutableArray array];
	for (NSString *p in [self recentDocumentURLs_wsbsd_paths]) [urls addObject: [NSURL fileURLWithPath: p]];
	return urls;
}
- (NSArray *)recentDocumentURLs_wsbsd_paths { return [self respondsToSelector: @selector(recentDocumentPaths)] ? [self performSelector: @selector(recentDocumentPaths)] : @[]; }
@end
@implementation NSAlert (WsbsdSuppression)
static const char suppressShowKey, suppressButtonKey;
- (BOOL)showsSuppressionButton { return [(NSNumber *)getAssoc(self, &suppressShowKey) boolValue]; }
- (void)setShowsSuppressionButton:(BOOL)f { setAssoc(self, &suppressShowKey, [NSNumber numberWithBool: f]); }
- (NSButton *)suppressionButton
{
	NSButton *b = getAssoc(self, &suppressButtonKey);
	if (!b) { b = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 200, 18)]; [b setButtonType: NSSwitchButton]; [b setTitle: @"Do not show this message again"]; setAssoc(self, &suppressButtonKey, b); }
	return b;
}
@end

@implementation NSControl (WsbsdEnabled)
@end
@implementation NSWindow (WsbsdStatus)
@end
@implementation NSTimer (WsbsdTolerance)
static const char tolKey;
- (NSTimeInterval)tolerance { return [(NSNumber *)getAssoc(self, &tolKey) doubleValue]; }
- (void)setTolerance:(NSTimeInterval)t { setAssoc(self, &tolKey, [NSNumber numberWithDouble: t]); }
@end

/* ---- the QuickLook panel: a class that accepts its settings and does nothing (Core Animation is the QuartzCore of this stack, see quartzcore/) ---- */
#import <Quartz/Quartz.h>
@implementation QLPreviewPanel
@synthesize dataSource, delegate, currentPreviewItemIndex;
+ (QLPreviewPanel *)sharedPreviewPanel { static QLPreviewPanel *p; if (!p) p = [[QLPreviewPanel alloc] initWithContentRect: NSMakeRect(0, 0, 400, 300) styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: YES]; return p; }
+ (BOOL)sharedPreviewPanelExists { return NO; }
- (void)reloadData {}
- (void)refreshCurrentPreviewItem {}
@end

@implementation NSSearchField (WsbsdSearch)
static const char sendsWholeKey, sendsImmKey;
- (BOOL)sendsWholeSearchString { return [(NSNumber *)getAssoc(self, &sendsWholeKey) boolValue]; }
- (void)setSendsWholeSearchString:(BOOL)f { setAssoc(self, &sendsWholeKey, [NSNumber numberWithBool: f]); }
- (BOOL)sendsSearchStringImmediately { return [(NSNumber *)getAssoc(self, &sendsImmKey) boolValue]; }
- (void)setSendsSearchStringImmediately:(BOOL)f { setAssoc(self, &sendsImmKey, [NSNumber numberWithBool: f]); }
@end

@implementation NSDocumentController (WsbsdClassProperties)
@end

@implementation NSWorkspaceOpenConfiguration
+ (instancetype)configuration { return [[self alloc] init]; }
@end
@implementation NSWorkspace (WsbsdOpenConfiguration)
- (void)openURLs:(NSArray *)urls withApplicationAtURL:(NSURL *)appURL configuration:(NSWorkspaceOpenConfiguration *)configuration completionHandler:(void (^)(NSRunningApplication *app, NSError *error))handler
{
	(void)configuration; BOOL ok = YES;
	for (NSURL *u in urls) ok = ([appURL isFileURL] ? [self openFile: [u path] withApplication: [appURL path]] : [self openFile: [u path]]) && ok;
	if (handler) handler(nil, ok ? nil : [NSError errorWithDomain: NSCocoaErrorDomain code: 4 userInfo: nil]);
}
@end

/* ---- NSWindowController asks -windowNibName on Apple (subclasses override it); GNUstep only looks at the name given to -initWithWindowNibName:, so a controller that overrides the method
 * got a nil nib path. The overridden name is used when there is none. ---- */
static IMP origWindowNibPath;
static NSString *wsbsdWindowNibPath(id self, SEL _cmd)
{
	NSString *p = ((NSString *(*)(id, SEL))origWindowNibPath)(self, _cmd);
	if (p) return p;
	NSString *name = [(NSWindowController *)self windowNibName];
	if (!name) return nil;
	id owner = [(NSWindowController *)self owner];
	p = [[NSBundle bundleForClass: [owner class]] pathForNibResource: name];
	return p ?: [[NSBundle mainBundle] pathForNibResource: name];
}
@interface WsbsdWindowControllerFix : NSObject @end
@implementation WsbsdWindowControllerFix
+ (void)load
{
	Class c = objc_getClass("NSWindowController");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("windowNibPath")) : NULL;
	if (m && !origWindowNibPath) origWindowNibPath = method_setImplementation(m, (IMP)wsbsdWindowNibPath);
}
@end
/* the private name AppKit gives the recent documents / windows menu (an application marks its menu with it); kept */
@implementation NSMenu (WsbsdMenuName)
static const char menuNameKey;
- (void)_setMenuName:(NSString *)name { setAssoc(self, &menuNameKey, name); }
- (NSString *)_menuName { return getAssoc(self, &menuNameKey); }
@end

/* ---- a table column without an identifier gets one ("AutomaticTableColumnIdentifier.N" on Apple); GNUstep's view-based table uses the identifier as a dictionary key and failed on nil ---- */
static IMP origColumnIdentifier;
static id wsbsdColumnIdentifier(id self, SEL _cmd)
{
	id ident = ((id (*)(id, SEL))origColumnIdentifier)(self, _cmd);
	if (ident) return ident;
	static int counter;
	NSString *auto_ = [NSString stringWithFormat: @"AutomaticTableColumnIdentifier.%d", counter++];
	[(NSTableColumn *)self setIdentifier: auto_];
	return auto_;
}
@interface WsbsdTableColumnFix : NSObject @end
@implementation WsbsdTableColumnFix
+ (void)load
{
	Class c = objc_getClass("NSTableColumn");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("identifier")) : NULL;
	if (m && !origColumnIdentifier) origColumnIdentifier = method_setImplementation(m, (IMP)wsbsdColumnIdentifier);
}
@end

/* ---- prototype cell views of a view-based table column without an identifier: GNUstep keys them by identifier; one is made up (they are looked up by column, never by that name) ---- */
static IMP origRegisterPrototypes;
static void wsbsdRegisterPrototypes(id self, SEL _cmd, NSArray *views)
{
	static int counter;
	for (NSView *v in views) if (![v identifier]) [v setIdentifier: [NSString stringWithFormat: @"AutomaticTableCellIdentifier.%d", counter++]];
	((void (*)(id, SEL, NSArray *))origRegisterPrototypes)(self, _cmd, views);
}
@interface WsbsdPrototypeFix : NSObject @end
@implementation WsbsdPrototypeFix
+ (void)load
{
	Class c = objc_getClass("NSTableView");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("_registerPrototypeViews:")) : NULL;
	if (m && !origRegisterPrototypes) origRegisterPrototypes = method_setImplementation(m, (IMP)wsbsdRegisterPrototypes);
}
@end

/* ---- a command-line argument that is a path: GNUstep opens it as a document at launch and shows an error alert when the application has no document types or delegate method for it (Pashua
 * and other tools take a config file as argument); macOS does not open command-line arguments. Without a delegate -application:openFile: and without document types it is ignored. ---- */
static IMP origServicesOpenFile;
static BOOL wsbsdServicesOpenFile(id self, SEL _cmd, id app, NSString *file)
{
	id delegate = [NSApp delegate];
	BOOL delegateOpens = delegate && ([delegate respondsToSelector: @selector(application:openFile:)] || [delegate respondsToSelector: @selector(application:openFiles:)]);
	BOOL hasTypes = [[[NSDocumentController sharedDocumentController] documentClassNames] count] > 0;
	if (!delegateOpens && !hasTypes) return NO;
	return ((BOOL (*)(id, SEL, id, NSString *))origServicesOpenFile)(self, _cmd, app, file);
}
@interface WsbsdOpenFileFix : NSObject @end
@implementation WsbsdOpenFileFix
+ (void)load
{
	Class c = objc_getClass("GSServicesManager");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("application:openFile:")) : NULL;
	if (m && !origServicesOpenFile) origServicesOpenFile = method_setImplementation(m, (IMP)wsbsdServicesOpenFile);
}
@end

@implementation NSURL (WsbsdBookmarks)
+ (instancetype)fileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
	NSString *p = path ? [[NSFileManager defaultManager] stringWithFileSystemRepresentation: path length: strlen(path)] : @"";
	if (baseURL && ![p hasPrefix: @"/"]) p = [[baseURL path] stringByAppendingPathComponent: p];
	return [NSURL fileURLWithPath: p isDirectory: isDir];
}
- (NSData *)bookmarkDataWithOptions:(NSUInteger)options includingResourceValuesForKeys:(NSArray *)keys relativeToURL:(NSURL *)relativeURL error:(NSError **)error
{
	(void)options; (void)keys; (void)relativeURL; (void)error;
	return [[self absoluteString] dataUsingEncoding: NSUTF8StringEncoding];
}
+ (instancetype)URLByResolvingBookmarkData:(NSData *)bookmarkData options:(NSUInteger)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error
{
	(void)options; (void)relativeURL; (void)error; if (isStale) *isStale = NO;
	NSString *s = [[NSString alloc] initWithData: bookmarkData encoding: NSUTF8StringEncoding];
	return s ? [NSURL URLWithString: s] : nil;
}
- (BOOL)startAccessingSecurityScopedResource { return YES; }
- (void)stopAccessingSecurityScopedResource {}
@end

@implementation NSFont (WsbsdWeights)
+ (NSFont *)systemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight { return weight >= 0.4 ? [NSFont boldSystemFontOfSize: size] : [NSFont systemFontOfSize: size]; }
+ (NSFont *)monospacedDigitSystemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight { return [self systemFontOfSize: size weight: weight]; }
+ (NSFont *)monospacedSystemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight { (void)weight; return [NSFont userFixedPitchFontOfSize: size]; }
@end

/* ---- NSURL resource values, computed from the file (GNUstep's answered with the wrong kind of object for several keys: a date where a BOOL is expected) ---- */
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
static id resourceValue(NSURL *u, NSString *key)
{
	if (![u isFileURL]) return nil;
	struct stat st, lst; const char *p = [[u path] fileSystemRepresentation];
	if (lstat(p, &lst) != 0) return nil;
	if (stat(p, &st) != 0) st = lst;
	BOOL dir = S_ISDIR(st.st_mode), pkg = dir && ([[[u path] pathExtension] length] > 0 && [@[@"app", @"framework", @"bundle", @"plugin", @"kext", @"xpc", @"appex"] containsObject: [[u path] pathExtension]]);
	if ([key isEqualToString: @"NSURLIsDirectoryKey"]) return [NSNumber numberWithBool: dir];
	if ([key isEqualToString: @"NSURLIsRegularFileKey"]) return [NSNumber numberWithBool: S_ISREG(st.st_mode)];
	if ([key isEqualToString: @"NSURLIsSymbolicLinkKey"]) return [NSNumber numberWithBool: S_ISLNK(lst.st_mode)];
	if ([key isEqualToString: @"NSURLIsPackageKey"]) return [NSNumber numberWithBool: pkg];
	if ([key isEqualToString: @"NSURLIsApplicationKey"]) return [NSNumber numberWithBool: pkg && [[[u path] pathExtension] isEqualToString: @"app"]];
	if ([key isEqualToString: @"NSURLIsHiddenKey"]) return [NSNumber numberWithBool: [[[u path] lastPathComponent] hasPrefix: @"."]];
	if ([key isEqualToString: @"NSURLIsReadableKey"]) return [NSNumber numberWithBool: access(p, R_OK) == 0];
	if ([key isEqualToString: @"NSURLIsWritableKey"]) return [NSNumber numberWithBool: access(p, W_OK) == 0];
	if ([key isEqualToString: @"NSURLIsExecutableKey"]) return [NSNumber numberWithBool: access(p, X_OK) == 0];
	if ([key isEqualToString: @"NSURLIsVolumeKey"]) return [NSNumber numberWithBool: [[u path] isEqualToString: @"/"]];
	if ([key isEqualToString: @"NSURLFileSizeKey"] || [key isEqualToString: @"NSURLTotalFileSizeKey"]) return [NSNumber numberWithLongLong: (long long)st.st_size];
	if ([key isEqualToString: @"NSURLFileAllocatedSizeKey"] || [key isEqualToString: @"NSURLTotalFileAllocatedSizeKey"]) return [NSNumber numberWithLongLong: (long long)st.st_blocks * 512];
	if ([key isEqualToString: @"NSURLContentModificationDateKey"]) return [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st.st_mtime];
	if ([key isEqualToString: @"NSURLAttributeModificationDateKey"]) return [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st.st_ctime];
	if ([key isEqualToString: @"NSURLContentAccessDateKey"]) return [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st.st_atime];
	if ([key isEqualToString: @"NSURLCreationDateKey"]) return [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st.st_birthtime];
	if ([key isEqualToString: @"NSURLNameKey"] || [key isEqualToString: @"NSURLLocalizedNameKey"]) return [[u path] lastPathComponent];
	if ([key isEqualToString: @"NSURLPathKey"]) return [u path];
	if ([key isEqualToString: @"NSURLLinkCountKey"]) return [NSNumber numberWithUnsignedLong: st.st_nlink];
	if ([key isEqualToString: @"NSURLVolumeURLKey"]) return [NSURL fileURLWithPath: @"/"];
	if ([key hasPrefix: @"NSURLVolume"]) {
		struct statfs sf; if (statfs(p, &sf) != 0) return nil;
		if ([key isEqualToString: @"NSURLVolumeAvailableCapacityKey"] || [key isEqualToString: @"NSURLVolumeAvailableCapacityForImportantUsageKey"] || [key isEqualToString: @"NSURLVolumeAvailableCapacityForOpportunisticUsageKey"]) return [NSNumber numberWithLongLong: (long long)sf.f_bavail * (long long)sf.f_bsize];
		if ([key isEqualToString: @"NSURLVolumeTotalCapacityKey"]) return [NSNumber numberWithLongLong: (long long)sf.f_blocks * (long long)sf.f_bsize];
		if ([key isEqualToString: @"NSURLVolumeLocalizedFormatDescriptionKey"] || [key isEqualToString: @"NSURLVolumeNameKey"] || [key isEqualToString: @"NSURLVolumeLocalizedNameKey"]) return [key isEqualToString: @"NSURLVolumeLocalizedFormatDescriptionKey"] ? [NSString stringWithUTF8String: sf.f_fstypename] : [NSString stringWithUTF8String: sf.f_mntonname];
		if ([key isEqualToString: @"NSURLVolumeIsLocalKey"]) return [NSNumber numberWithBool: (sf.f_flags & MNT_LOCAL) != 0];
		if ([key isEqualToString: @"NSURLVolumeIsReadOnlyKey"]) return [NSNumber numberWithBool: (sf.f_flags & MNT_RDONLY) != 0];
		if ([key isEqualToString: @"NSURLVolumeURLKey"]) return [NSURL fileURLWithPath: [NSString stringWithUTF8String: sf.f_mntonname]];
	}
	if ([key isEqualToString: @"NSURLTypeIdentifierKey"]) return dir ? (pkg ? @"com.apple.application-bundle" : @"public.folder") : @"public.data";
	return nil;
}
static IMP origGetResource, origResourceValues;
static BOOL wsbsdGetResourceValue(id self, SEL _cmd, id *value, NSString *key, NSError **error)
{
	id v = resourceValue(self, key);
	if (!v) {
		if (origGetResource && ((BOOL (*)(id, SEL, id *, id, NSError **))origGetResource)(self, _cmd, value, key, error)) return YES;
		if (error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: [NSDictionary dictionaryWithObject: [NSString stringWithFormat: @"No value for %@", key] forKey: NSLocalizedDescriptionKey]];
		return NO;
	}
	if (value) *value = v;
	return YES;
}
static NSDictionary *wsbsdResourceValues(id self, SEL _cmd, NSArray *keys, NSError **error)
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	for (NSString *k in keys) { id v = resourceValue(self, k); if (v) [d setObject: v forKey: k]; }
	return d;
}
@interface WsbsdURLResourceFix : NSObject @end
@implementation WsbsdURLResourceFix
+ (void)load
{
	Class c = objc_getClass("NSURL");
	Method m = c ? class_getInstanceMethod(c, sel_registerName("getResourceValue:forKey:error:")) : NULL;
	if (m && !origGetResource) origGetResource = method_setImplementation(m, (IMP)wsbsdGetResourceValue);
	else if (c && !origGetResource) { class_addMethod(c, sel_registerName("getResourceValue:forKey:error:"), (IMP)wsbsdGetResourceValue, "c@:^@@^@"); }
	m = c ? class_getInstanceMethod(c, sel_registerName("resourceValuesForKeys:error:")) : NULL;
	if (m && !origResourceValues) origResourceValues = method_setImplementation(m, (IMP)wsbsdResourceValues);
	else if (c && !origResourceValues) class_addMethod(c, sel_registerName("resourceValuesForKeys:error:"), (IMP)wsbsdResourceValues, "@@:@^@");
}
@end

/* an xib image resource GNUstep could not find stays a string, and the loader then sets its "template" attribute on it: a harmless no-op instead of an exception that aborts the whole nib */
@implementation NSString (WsbsdXibImageTemplate)
- (void)setTemplate:(BOOL)flag { (void)flag; }
- (NSSize)size { return NSZeroSize; }
- (void)setSize:(NSSize)size { (void)size; }
@end

@implementation NSImage (WsbsdSymbols)
+ (instancetype)imageWithSystemSymbolName:(NSString *)name accessibilityDescription:(NSString *)description
{
	if (!name.length) return nil;
	NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(18, 18)];
	[img lockFocus];
	[[NSColor blackColor] set];
	NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(2.5, 2.5, 13, 13) xRadius: 3 yRadius: 3]; [p setLineWidth: 1.5]; [p stroke];
	NSString *g = [[name substringToIndex: 1] uppercaseString];
	NSDictionary *a = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 9], NSForegroundColorAttributeName: [NSColor blackColor] };
	NSSize sz = [g sizeWithAttributes: a]; [g drawAtPoint: NSMakePoint(9 - sz.width / 2, 9 - sz.height / 2) withAttributes: a];
	[img unlockFocus];
	[img setTemplate: YES];
	return img;
}
@end

@implementation NSWindow (WsbsdTermination)
- (void)setPreventsApplicationTerminationWhenModal:(BOOL)flag {}
- (BOOL)preventsApplicationTerminationWhenModal { return NO; }
@end
@implementation NSWorkspace (WsbsdLaunchServices)
- (NSURL *)URLForApplicationToOpenURL:(NSURL *)url { return nil; }
- (NSArray<NSURL *> *)URLsForApplicationsToOpenURL:(NSURL *)url { return @[]; }
@end
@implementation NSString (WsbsdLocalizedCase)
- (NSString *)localizedCapitalizedString { return [self capitalizedString]; }
- (NSString *)localizedLowercaseString { return [self lowercaseString]; }
- (NSString *)localizedUppercaseString { return [self uppercaseString]; }
@end

@implementation NSFileManager (WsbsdTrash)
/* the item is moved into ~/.Trash (the FreeDesktop trash folder layout is not used) under a free name */
- (BOOL)trashItemAtURL:(NSURL *)url resultingItemURL:(NSURL **)outResultingURL error:(NSError **)error
{
	NSString *trash = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"];
	[self createDirectoryAtPath: trash withIntermediateDirectories: YES attributes: nil error: nil];
	NSString *name = [[url path] lastPathComponent], *dest = [trash stringByAppendingPathComponent: name];
	for (int i = 2; [self fileExistsAtPath: dest]; i++) dest = [trash stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %d.%@", [name stringByDeletingPathExtension], i, [name pathExtension]]];
	if (![self moveItemAtPath: [url path] toPath: dest error: error]) return NO;
	if (outResultingURL) *outResultingURL = [NSURL fileURLWithPath: dest];
	return YES;
}
@end

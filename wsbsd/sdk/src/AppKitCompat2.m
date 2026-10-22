/* sdk/include/wsbsd/AppKitCompat2.h */
#import <wsbsd/AppKitCompat2.h>
#import <objc/runtime.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation NSURL (WsbsdFS)
- (const char *)fileSystemRepresentation { return [[self path] fileSystemRepresentation]; }
- (BOOL)hasDirectoryPath
{
	NSString *r = [self relativeString];
	NSRange q = [r rangeOfCharacterFromSet: [NSCharacterSet characterSetWithCharactersInString: @"?#"]];
	if (q.length) r = [r substringToIndex: q.location];
	return [r hasSuffix: @"/"];
}
@end

/* an image drawn by a block each time it is drawn: the destination rectangle is mapped onto the image's own size (flipped when the caller asked for a flipped context) */
@interface WsbsdHandlerImage : NSImage { BOOL (^_handler)(NSRect); BOOL _flip; }
- (id)initWithSize:(NSSize)size flipped:(BOOL)flip handler:(BOOL (^)(NSRect))h;
@end
@implementation WsbsdHandlerImage
- (id)initWithSize:(NSSize)size flipped:(BOOL)flip handler:(BOOL (^)(NSRect))h { if ((self = [super initWithSize: size])) { _flip = flip; _handler = [h copy]; } return self; }
- (void)wsbsdDrawIn:(NSRect)dst fraction:(CGFloat)f flipped:(BOOL)contextFlipped
{
	NSSize s = [self size]; if (s.width <= 0 || s.height <= 0 || !_handler) return;
	NSGraphicsContext *gc = [NSGraphicsContext currentContext]; [gc saveGraphicsState];
	NSAffineTransform *t = [NSAffineTransform transform];
	BOOL flipAxis = (_flip != contextFlipped);                                          /* the image's content is y-up unless it asked for a flipped context */
	[t translateXBy: dst.origin.x yBy: flipAxis ? NSMaxY(dst) : dst.origin.y]; [t scaleXBy: dst.size.width / s.width yBy: (flipAxis ? -1 : 1) * dst.size.height / s.height]; [t concat];
	if (f < 1) { /* partial opacity is not applied to a block's drawing */ }
	_handler(NSMakeRect(0, 0, s.width, s.height));
	[gc restoreGraphicsState];
}
- (void)drawInRect:(NSRect)r fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f respectFlipped:(BOOL)flip hints:(NSDictionary *)h { [self wsbsdDrawIn: r fraction: f flipped: flip ? [[NSView focusView] isFlipped] : NO]; }
- (void)drawInRect:(NSRect)r fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsbsdDrawIn: r fraction: f flipped: NO]; }
- (void)drawInRect:(NSRect)r { [self wsbsdDrawIn: r fraction: 1 flipped: NO]; }
- (void)drawAtPoint:(NSPoint)p fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsbsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: f flipped: NO]; }
- (void)compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op { [self drawAtPoint: p fromRect: NSZeroRect operation: op fraction: 1]; }
- (void)compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self drawAtPoint: p fromRect: NSZeroRect operation: op fraction: f]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
static char kAXDesc;
@implementation NSImage (WsbsdDrawing)
+ (NSImage *)imageWithSize:(NSSize)size flipped:(BOOL)flip drawingHandler:(BOOL (^)(NSRect))handler { return [[WsbsdHandlerImage alloc] initWithSize: size flipped: flip handler: handler]; }
- (NSString *)accessibilityDescription { return objc_getAssociatedObject(self, &kAXDesc); }
- (void)setAccessibilityDescription:(NSString *)d { objc_setAssociatedObject(self, &kAXDesc, d, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end

NSString *const NSAccessibilityException = @"NSAccessibilityException";
static char kAX;
static id AXGet(id o, const char *k) { NSDictionary *d = objc_getAssociatedObject(o, &kAX); return d[[NSString stringWithUTF8String: k]]; }
static void AXSet(id o, const char *k, id v)
{
	NSMutableDictionary *d = objc_getAssociatedObject(o, &kAX); if (!d) { d = [NSMutableDictionary new]; objc_setAssociatedObject(o, &kAX, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	NSString *key = [NSString stringWithUTF8String: k]; if (v) d[key] = v; else [d removeObjectForKey: key];
}
@implementation NSObject (WsbsdAccessibility)
- (id)accessibilityAttributeValue:(NSString *)attribute { return AXGet(self, [[@"attr:" stringByAppendingString: attribute] UTF8String]); }
- (id)accessibilityAttributeValue:(NSString *)attribute forParameter:(id)parameter { return nil; }
- (BOOL)accessibilitySetOverrideValue:(id)value forAttribute:(NSString *)attribute { AXSet(self, [[@"attr:" stringByAppendingString: attribute] UTF8String], value); return YES; }
#define AXSTR(Getter, Setter, Key) - (NSString *)Getter { return AXGet(self, Key); } - (void)Setter:(NSString *)v { AXSet(self, Key, [v copy]); }
AXSTR(accessibilityLabel, setAccessibilityLabel, "label")
AXSTR(accessibilityTitle, setAccessibilityTitle, "title")
AXSTR(accessibilityHelp, setAccessibilityHelp, "help")
AXSTR(accessibilityIdentifier, setAccessibilityIdentifier, "identifier")
AXSTR(accessibilityRole, setAccessibilityRole, "role")
AXSTR(accessibilityRoleDescription, setAccessibilityRoleDescription, "roleDescription")
AXSTR(accessibilitySubrole, setAccessibilitySubrole, "subrole")
AXSTR(accessibilityPlaceholderValue, setAccessibilityPlaceholderValue, "placeholder")
- (id)accessibilityValue { return AXGet(self, "value"); }
- (void)setAccessibilityValue:(id)v { AXSet(self, "value", v); }
- (BOOL)isAccessibilityElement { return [AXGet(self, "element") boolValue]; }
- (void)setAccessibilityElement:(BOOL)b { AXSet(self, "element", @(b)); }
@end

@interface WsbsdCGColorBox : NSObject { @public CGColorRef c; } @end
@implementation WsbsdCGColorBox
- (void)dealloc { if (c) CGColorRelease(c); }
@end
static char kCG;
@implementation NSColor (WsbsdCG)
+ (NSColor *)colorWithCGColor:(CGColorRef)c
{
	if (!c) return nil;
	size_t n = CGColorGetNumberOfComponents(c); const CGFloat *p = CGColorGetComponents(c);
	if (n >= 4) return [NSColor colorWithCalibratedRed: p[0] green: p[1] blue: p[2] alpha: p[n - 1]];
	if (n == 2) return [NSColor colorWithCalibratedWhite: p[0] alpha: p[1]];
	if (n == 1) return [NSColor colorWithCalibratedWhite: p[0] alpha: CGColorGetAlpha(c)];
	return [NSColor clearColor];
}
- (CGColorRef)CGColor
{
	WsbsdCGColorBox *b = objc_getAssociatedObject(self, &kCG); if (b) return b->c;
	NSColor *rgb = [self colorUsingColorSpaceName: NSCalibratedRGBColorSpace]; if (!rgb) rgb = [NSColor blackColor];
	CGFloat r, g, bl, a; [rgb getRed: &r green: &g blue: &bl alpha: &a];
	b = [WsbsdCGColorBox new]; b->c = CGColorCreateGenericRGB(r, g, bl, a);
	objc_setAssociatedObject(self, &kCG, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return b->c;
}
@end

static char kVCID;
@implementation NSViewController (WsbsdHierarchy)
- (NSString *)identifier { return objc_getAssociatedObject(self, &kVCID); }
- (void)setIdentifier:(NSString *)i { objc_setAssociatedObject(self, &kVCID, i, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end

NSDictionary *_NSDictionaryOfVariableBindings(NSString *keys, id first, ...)
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	NSArray *names = [keys componentsSeparatedByString: @","];
	va_list ap; va_start(ap, first); id v = first;
	for (NSString *n in names) { NSString *k = [n stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]; if (!v) break; d[k] = v; v = va_arg(ap, id); }
	va_end(ap); return d;
}
NSString *const NSFontFeatureTypeIdentifierKey = @"CTFeatureTypeIdentifier";
NSString *const NSFontFeatureSelectorIdentifierKey = @"CTFeatureSelectorIdentifier";
NSString *const NSFontFeatureSettingsAttribute = @"NSCTFontFeatureSettingsAttribute";

/* ---- CFUserNotification and Launch Services over AppKit ---- */
#import <CoreFoundation/CFUserNotification.h>
#import <CoreServices/LaunchServices.h>
int32_t CFUserNotificationDisplayAlert(CFTimeInterval timeout, CFOptionFlags flags, CFURLRef iconURL, CFURLRef soundURL, CFURLRef localizationURL, CFStringRef alertHeader, CFStringRef alertMessage,
                                       CFStringRef defaultButtonTitle, CFStringRef alternateButtonTitle, CFStringRef otherButtonTitle, CFOptionFlags *responseFlags)
{
	(void)timeout; (void)iconURL; (void)soundURL; (void)localizationURL;
	@autoreleasepool {
		NSAlert *a = [[NSAlert alloc] init];
		[a setMessageText: (__bridge NSString *)alertHeader ?: @""]; [a setInformativeText: (__bridge NSString *)alertMessage ?: @""];
		[a setAlertStyle: (flags & 3) == kCFUserNotificationStopAlertLevel ? NSAlertStyleCritical : (flags & 3) == kCFUserNotificationCautionAlertLevel ? NSAlertStyleWarning : NSAlertStyleInformational];
		[a addButtonWithTitle: (__bridge NSString *)defaultButtonTitle ?: @"OK"];
		if (alternateButtonTitle) [a addButtonWithTitle: (__bridge NSString *)alternateButtonTitle];
		if (otherButtonTitle) [a addButtonWithTitle: (__bridge NSString *)otherButtonTitle];
		NSInteger r = [a runModal]; CFOptionFlags out = kCFUserNotificationCancelResponse;
		if (r == NSAlertFirstButtonReturn) out = kCFUserNotificationDefaultResponse; else if (r == NSAlertSecondButtonReturn) out = kCFUserNotificationAlternateResponse; else if (r == NSAlertThirdButtonReturn) out = kCFUserNotificationOtherResponse;
		if (responseFlags) *responseFlags = out;
	}
	return 0;
}
int32_t LSOpenURLsWithRole(CFArrayRef inURLs, LSRolesMask inRole, const void *inAEParam, const void *inAppParams, CFArrayRef *outLaunchedURLs, CFIndex inMaxLaunchedURLs)
{
	(void)inRole; (void)inAEParam; (void)inAppParams; if (outLaunchedURLs) *outLaunchedURLs = NULL; (void)inMaxLaunchedURLs;
	BOOL ok = YES; for (NSURL *u in (__bridge NSArray *)inURLs) ok = [[NSWorkspace sharedWorkspace] openURL: u] && ok;
	return ok ? 0 : -43;
}

/* ---- CFPreferences over NSUserDefaults ---- */
#import <CoreFoundation/CFPreferences.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>
static BOOL IsCurrentApp(CFStringRef app) { return !app || CFEqual(app, kCFPreferencesCurrentApplication) || CFEqual(app, kCFPreferencesAnyApplication); }
CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef app)
{
	NSString *k = (__bridge NSString *)key; id v;
	if (IsCurrentApp(app)) v = [[NSUserDefaults standardUserDefaults] objectForKey: k];
	else v = [[[NSUserDefaults standardUserDefaults] persistentDomainForName: (__bridge NSString *)app] objectForKey: k];
	if ([v isKindOfClass: [NSNumber class]] && !strcmp([v objCType], @encode(BOOL)) ) return CFRetain([v boolValue] ? kCFBooleanTrue : kCFBooleanFalse);     /* a boolean comes back as a CFBoolean */
	return v ? CFBridgingRetain(v) : NULL;
}
Boolean CFPreferencesGetAppBooleanValue(CFStringRef key, CFStringRef app, Boolean *ok)
{
	CFTypeRef c = CFPreferencesCopyAppValue(key, app); Boolean good = false, v = false;
	if (c) {
		if (CFGetTypeID(c) == CFBooleanGetTypeID()) { good = true; v = CFBooleanGetValue(c); }
		else { id o = (__bridge id)c; if ([o isKindOfClass: [NSNumber class]] || [o isKindOfClass: [NSString class]]) { good = true; v = [o boolValue]; } }
		CFRelease(c);
	}
	if (ok) *ok = good; return v;
}
CFIndex CFPreferencesGetAppIntegerValue(CFStringRef key, CFStringRef app, Boolean *ok)
{
	CFTypeRef c = CFPreferencesCopyAppValue(key, app); Boolean good = false; CFIndex v = 0;
	if (c) { id o = (__bridge id)c; if ([o isKindOfClass: [NSNumber class]] || [o isKindOfClass: [NSString class]]) { good = true; v = [o integerValue]; } CFRelease(c); }
	if (ok) *ok = good; return v;
}
void CFPreferencesSetAppValue(CFStringRef key, CFPropertyListRef value, CFStringRef app)
{
	NSString *k = (__bridge NSString *)key;
	id obj = !value ? nil : (CFGetTypeID(value) == CFBooleanGetTypeID()) ? (id)[NSNumber numberWithBool: CFBooleanGetValue(value)] : (__bridge id)value;
	if (IsCurrentApp(app)) { if (value) [[NSUserDefaults standardUserDefaults] setObject: obj forKey: k]; else [[NSUserDefaults standardUserDefaults] removeObjectForKey: k]; return; }
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; NSMutableDictionary *dom = [[d persistentDomainForName: (__bridge NSString *)app] mutableCopy] ?: [NSMutableDictionary dictionary];
	if (value) dom[k] = obj; else [dom removeObjectForKey: k]; [d setPersistentDomain: dom forName: (__bridge NSString *)app];
}
Boolean CFPreferencesAppSynchronize(CFStringRef app) { (void)app; return [[NSUserDefaults standardUserDefaults] synchronize]; }
CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef app, CFStringRef user, CFStringRef host) { (void)user; (void)host; return CFPreferencesCopyAppValue(key, app); }
void CFPreferencesSetValue(CFStringRef key, CFPropertyListRef value, CFStringRef app, CFStringRef user, CFStringRef host) { (void)user; (void)host; CFPreferencesSetAppValue(key, value, app); }
Boolean CFPreferencesSynchronize(CFStringRef app, CFStringRef user, CFStringRef host) { (void)user; (void)host; return CFPreferencesAppSynchronize(app); }
CFArrayRef CFPreferencesCopyKeyList(CFStringRef app, CFStringRef user, CFStringRef host)
{
	(void)user; (void)host; NSDictionary *d = IsCurrentApp(app) ? [[NSUserDefaults standardUserDefaults] dictionaryRepresentation] : [[NSUserDefaults standardUserDefaults] persistentDomainForName: (__bridge NSString *)app];
	return d ? CFBridgingRetain([d allKeys]) : NULL;
}

/* ---- proxies from the environment ---- */
static BOOL SplitProxy(const char *env, NSString **host, int *port)                    /* "http://user@host:port/" -> host, port */
{
	const char *v = getenv(env); if (!v || !*v) return NO;
	NSURL *u = [NSURL URLWithString: [[NSString stringWithUTF8String: v] containsString: @"://"] ? [NSString stringWithUTF8String: v] : [@"http://" stringByAppendingString: [NSString stringWithUTF8String: v]]];
	if (![u host]) return NO; *host = [u host]; *port = [u port] ? [[u port] intValue] : 80; return YES;
}
CFDictionaryRef CFNetworkCopySystemProxySettings(void)
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSString *h; int p;
	if (SplitProxy("http_proxy", &h, &p) || SplitProxy("HTTP_PROXY", &h, &p) || SplitProxy("all_proxy", &h, &p)) { d[@"HTTPEnable"] = @1; d[@"HTTPProxy"] = h; d[@"HTTPPort"] = @(p); }
	if (SplitProxy("https_proxy", &h, &p) || SplitProxy("HTTPS_PROXY", &h, &p)) { d[@"HTTPSEnable"] = @1; d[@"HTTPSProxy"] = h; d[@"HTTPSPort"] = @(p); }
	const char *no = getenv("no_proxy"); if (!no) no = getenv("NO_PROXY"); if (no && *no) d[@"ExceptionsList"] = [[NSString stringWithUTF8String: no] componentsSeparatedByString: @","];
	return (CFDictionaryRef)CFBridgingRetain(d);
}
CFDictionaryRef SCDynamicStoreCopyProxies(SCDynamicStoreRef store) { (void)store; return CFNetworkCopySystemProxySettings(); }
static CFArrayRef RetArray(NSArray *a) { return (CFArrayRef)CFBridgingRetain(a); }          /* a function: the commas of an array literal confuse CFBridgingRetain as a macro */
CFArrayRef CFNetworkCopyProxiesForURL(CFURLRef url, CFDictionaryRef settings)
{
	NSDictionary *s = (__bridge NSDictionary *)settings;
	NSString *host = (NSString *)CFBridgingRelease(CFURLCopyHostName(url)), *scheme = [(NSString *)CFBridgingRelease(CFURLCopyScheme(url)) lowercaseString];
	NSDictionary *none = @{ (__bridge NSString *)kCFProxyTypeKey: (__bridge NSString *)kCFProxyTypeNone };
	for (NSString *ex in s[@"ExceptionsList"]) { NSString *e = [ex stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]; if ([e hasPrefix: @"."] ? [host hasSuffix: e] : [host isEqualToString: e]) return RetArray(@[ none ]); }
	BOOL https = [scheme isEqualToString: @"https"];
	if ([s[https ? @"HTTPSEnable" : @"HTTPEnable"] boolValue])
		return RetArray(@[ @{ (__bridge NSString *)kCFProxyTypeKey: (__bridge NSString *)(https ? kCFProxyTypeHTTPS : kCFProxyTypeHTTP), (__bridge NSString *)kCFProxyHostNameKey: s[https ? @"HTTPSProxy" : @"HTTPProxy"],
			(__bridge NSString *)kCFProxyPortNumberKey: s[https ? @"HTTPSPort" : @"HTTPPort"] } ]);
	return RetArray(@[ none ]);
}
CFRunLoopSourceRef CFNetworkExecuteProxyAutoConfigurationURL(CFURLRef pacURL, CFURLRef target, CFProxyAutoConfigurationResultCallback cb, CFStreamClientContext *ctx)
{
	(void)pacURL; (void)target; (void)cb; (void)ctx; return NULL;                    /* PAC scripts are not run: the caller sees no source and goes on without a proxy */
}

/* ---- AppKit names ---- */
NSString *const NSImageBinding = @"image";
@implementation NSObject (WsbsdMenuDelegateProperties)
- (NSMenuProperties)propertiesToUpdate { return NSMenuPropertyItemTitle | NSMenuPropertyItemAttributedTitle | NSMenuPropertyItemKeyEquivalent | NSMenuPropertyItemImage | NSMenuPropertyItemEnabled; }
@end
@implementation NSStringDrawingContext
{ CGFloat _minScale, _minTracking; NSRect _total; }
@synthesize minimumScaleFactor = _minScale, minimumTrackingAdjustment = _minTracking;
- (CGFloat)actualScaleFactor { return 1; }
- (CGFloat)actualTrackingAdjustment { return 0; }
- (NSRect)totalBounds { return _total; }
- (void)wsbsdSetTotal:(NSRect)r { _total = r; }
@end
@implementation NSString (WsbsdDrawingContext)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(NSStringDrawingContext *)context
{
	NSRect r = [self boundingRectWithSize: size options: options attributes: attributes]; [context wsbsdSetTotal: r]; return r;
}
@end
@implementation NSAttributedString (WsbsdDrawingContext)
- (NSRect)boundingRectWithSize:(NSSize)size options:(NSStringDrawingOptions)options context:(NSStringDrawingContext *)context
{
	NSRect r = [self boundingRectWithSize: size options: options]; [context wsbsdSetTotal: r]; return r;
}
@end
@implementation NSWorkspace (WsbsdFileViewer)
- (void)activateFileViewerSelectingURLs:(NSArray *)urls { for (NSURL *u in urls) [self selectFile: [u path] inFileViewerRootedAtPath: @""]; }
@end
static char kTAC;
@implementation NSWindow (WsbsdTitlebarAccessories)
- (NSArray *)titlebarAccessoryViewControllers { return [objc_getAssociatedObject(self, &kTAC) copy] ?: @[]; }
- (void)insertTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)vc atIndex:(NSInteger)i
{
	NSMutableArray *a = [objc_getAssociatedObject(self, &kTAC) mutableCopy] ?: [NSMutableArray array]; if (i < 0 || i > (NSInteger)[a count]) i = (NSInteger)[a count];
	[a insertObject: vc atIndex: (NSUInteger)i]; objc_setAssociatedObject(self, &kTAC, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC);                    /* kept; the title bar draws no accessory yet */
}
- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)vc { [self insertTitlebarAccessoryViewController: vc atIndex: -1]; }
- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)i
{
	NSMutableArray *a = [objc_getAssociatedObject(self, &kTAC) mutableCopy]; if (i >= 0 && i < (NSInteger)[a count]) { [a removeObjectAtIndex: (NSUInteger)i]; objc_setAssociatedObject(self, &kTAC, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
@end

NSString *const NSImageNameApplicationIcon = @"NSApplicationIcon";
NSString *const NSProgressFileOperationKindKey = @"NSProgressFileOperationKindKey";
NSString *const NSProgressFileOperationKindDownloading = @"NSProgressFileOperationKindDownloading";
NSString *const NSProgressFileOperationKindCopying = @"NSProgressFileOperationKindCopying";
NSRect NSAccessibilityFrameInView(NSView *parent, NSRect frame)                                       /* the frame in screen coordinates */
{
	NSRect r = [parent convertRect: frame toView: nil]; r.origin = [[parent window] convertBaseToScreen: r.origin];
	return r;
}
@implementation NSView (WsbsdFitting)
- (NSSize)fittingSize                                                                                     /* what the view needs: its intrinsic size, else the size it has */
{
	NSSize s = [self intrinsicContentSize]; NSSize f = [self frame].size;
	return NSMakeSize(s.width >= 0 ? s.width : f.width, s.height >= 0 ? s.height : f.height);
}
@end
@implementation NSResponder (WsbsdRestoration)
- (void)invalidateRestorableState { }                                                                      /* there is no state restoration: nothing to invalidate */
@end

/* ---- Foundation / AppKit odds and ends ---- */
@implementation NSIndexSet (WsbsdTests)
- (NSIndexSet *)indexesInRange:(NSRange)range options:(NSEnumerationOptions)opts passingTest:(BOOL (^)(NSUInteger, BOOL *))test
{
	NSMutableIndexSet *out = [NSMutableIndexSet indexSet]; __block BOOL stop = NO;
	NSEnumerationOptions o = opts & NSEnumerationReverse;
	[self enumerateIndexesInRange: range options: o usingBlock: ^(NSUInteger i, BOOL *s) { if (test(i, &stop)) [out addIndex: i]; if (stop) *s = YES; }];
	return out;
}
- (NSIndexSet *)indexesWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(NSUInteger, BOOL *))test { return [self indexesInRange: NSMakeRange(0, NSUIntegerMax) options: opts passingTest: test]; }
- (NSIndexSet *)indexesPassingTest:(BOOL (^)(NSUInteger, BOOL *))test { return [self indexesWithOptions: 0 passingTest: test]; }
@end
@implementation NSFileManager (WsbsdReplace)
- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error
{
	char buf[PATH_MAX]; ssize_t n = readlink([path fileSystemRepresentation], buf, sizeof buf - 1);
	if (n < 0) { if (error) *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]; return nil; }
	return [self stringWithFileSystemRepresentation: buf length: (NSUInteger)n];
}
- (BOOL)replaceItemAtURL:(NSURL *)orig withItemAtURL:(NSURL *)new backupItemName:(NSString *)backup options:(NSFileManagerItemReplacementOptions)opts resultingItemURL:(NSURL **)result error:(NSError **)error
{
	NSString *o = [orig path], *n = [new path]; NSString *bak = backup ? [[o stringByDeletingLastPathComponent] stringByAppendingPathComponent: backup] : nil;
	if ([self fileExistsAtPath: o]) {
		if (bak) { [self removeItemAtPath: bak error: NULL]; if (rename([o fileSystemRepresentation], [bak fileSystemRepresentation]) != 0) goto fail; }
		else { NSString *tmp = [o stringByAppendingString: @".wsbsd-old"]; if (rename([o fileSystemRepresentation], [tmp fileSystemRepresentation]) != 0) goto fail; [self removeItemAtPath: tmp error: NULL]; }
	}
	if (rename([n fileSystemRepresentation], [o fileSystemRepresentation]) != 0) goto fail;
	if (result) *result = orig; return YES;
fail:
	if (error) *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]; return NO;
}
@end
@implementation NSUserDefaults (WsbsdSuite)
- (instancetype)initWithSuiteName:(NSString *)suite
{
	if (!suite || [suite isEqual: [[NSBundle mainBundle] bundleIdentifier]]) return [NSUserDefaults standardUserDefaults];
	NSUserDefaults *d = [[NSUserDefaults alloc] initWithUser: NSUserName()]; [d addSuiteNamed: suite]; return d;
}
@end
static char kHelpMenu, kMenuFont, kAnimBehavior, kGroupRows;
@interface NSObject (WsbsdDarkProbe) + (BOOL)isDark; @end
@implementation NSApplication (WsbsdHelpMenu)
- (NSMenu *)helpMenu { return objc_getAssociatedObject(self, &kHelpMenu); }
- (void)setHelpMenu:(NSMenu *)m { objc_setAssociatedObject(self, &kHelpMenu, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSAppearance *)effectiveAppearance { const char *e = getenv("WSD_APPEARANCE"); Class sup = NSClassFromString(@"WsdFinderSupport"); BOOL light = e ? !strcmp(e, "light") : (sup && [(id)sup respondsToSelector: @selector(isDark)] ? ![(id)sup isDark] : NO); return [NSAppearance appearanceNamed: light ? @"NSAppearanceNameAqua" : @"NSAppearanceNameDarkAqua"]; }
@end
@implementation NSMenu (WsbsdFont)
- (NSFont *)font { return objc_getAssociatedObject(self, &kMenuFont) ?: [NSFont menuFontOfSize: 0]; }
- (void)setFont:(NSFont *)f { objc_setAssociatedObject(self, &kMenuFont, f, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation NSWindow (WsbsdAnimationBehavior)
- (NSWindowAnimationBehavior)animationBehavior { return (NSWindowAnimationBehavior)[objc_getAssociatedObject(self, &kAnimBehavior) integerValue]; }
- (void)setAnimationBehavior:(NSWindowAnimationBehavior)b { objc_setAssociatedObject(self, &kAnimBehavior, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation NSTableView (WsbsdGroupRows)
- (BOOL)floatsGroupRows { NSNumber *n = objc_getAssociatedObject(self, &kGroupRows); return n ? [n boolValue] : YES; }
- (void)setFloatsGroupRows:(BOOL)b { objc_setAssociatedObject(self, &kGroupRows, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay: YES]; }
@end
@implementation NSOutlineView (WsbsdItemAnimation)                                                          /* the data source has already changed: the parent's children are read again */
- (void)insertItemsAtIndexes:(NSIndexSet *)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)o { [self reloadItem: parent reloadChildren: YES]; }
- (void)removeItemsAtIndexes:(NSIndexSet *)indexes inParent:(id)parent withAnimation:(NSTableViewAnimationOptions)o { [self reloadItem: parent reloadChildren: YES]; }
- (void)moveItemAtIndex:(NSInteger)from inParent:(id)oldParent toIndex:(NSInteger)to inParent:(id)newParent { [self reloadItem: oldParent reloadChildren: YES]; if (newParent != oldParent) [self reloadItem: newParent reloadChildren: YES]; }
@end

static char kTACHidden;
@implementation NSTitlebarAccessoryViewController (WsbsdHidden)
- (BOOL)isHidden { return [objc_getAssociatedObject(self, &kTACHidden) boolValue]; }
- (void)setHidden:(BOOL)h { objc_setAssociatedObject(self, &kTACHidden, @(h), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation NSFileManager (WsbsdLinks)
- (BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)dest error:(NSError **)error
{
	return [self createSymbolicLinkAtPath: [url path] withDestinationPath: [dest path] error: error];
}
- (BOOL)getRelationship:(NSInteger *)rel ofDirectory:(NSSearchPathDirectory)dir inDomain:(NSSearchPathDomainMask)mask toItemAtURL:(NSURL *)url error:(NSError **)error
{
	NSString *p = [[url path] stringByStandardizingPath]; NSString *home = NSHomeDirectory(); BOOL in = NO;
	if (dir == NSTrashDirectory) in = [p hasPrefix: [home stringByAppendingPathComponent: @".Trash/"]] || [p rangeOfString: @"/.Trashes/"].length > 0;      /* 0: contains, 1: same, 2: other */
	else { NSArray *ds = NSSearchPathForDirectoriesInDomains(dir, mask, YES); for (NSString *d in ds) if ([p hasPrefix: [d stringByAppendingString: @"/"]]) in = YES; }
	*rel = in ? 0 : 2; return YES;
}
@end

#import <QuickLook/QuickLook.h>

@implementation NSData (WsbsdRanges)
- (void)enumerateByteRangesUsingBlock:(void (^)(const void *, NSRange, BOOL *))block { BOOL stop = NO; block([self bytes], NSMakeRange(0, [self length]), &stop); }      /* the data is one contiguous range */
@end
@implementation NSWorkspace (WsbsdBundleLookup)
- (NSURL *)URLForApplicationWithBundleIdentifier:(NSString *)bid
{
	for (NSString *dir in @[ @"/Applications", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"], @"/System/Applications", @"/usr/local/GNUstep/Local/Applications" ])
		for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir error: NULL]) {
			if (![f hasSuffix: @".app"]) continue; NSString *p = [dir stringByAppendingPathComponent: f];
			if ([[[NSBundle bundleWithPath: p] bundleIdentifier] isEqual: bid]) return [NSURL fileURLWithPath: p];
		}
	return nil;
}
@end
NSString *const NSWorkspaceLaunchConfigurationArguments = @"NSWorkspaceLaunchConfigurationArguments";
NSString *const NSWorkspaceLaunchConfigurationEnvironment = @"NSWorkspaceLaunchConfigurationEnvironment";

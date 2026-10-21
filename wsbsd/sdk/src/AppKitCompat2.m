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

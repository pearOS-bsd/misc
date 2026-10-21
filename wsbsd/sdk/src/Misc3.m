/* Icon Services (IconRef -> NSImage), the URL scheme handler registry, OSAScript from a file, and the AppKit odds and ends of AppKitCompat2.h added with them */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat2.h>
#import <OSAKit/OSAKit.h>
#include <CoreServices/CoreServices.h>

/* IconRef: the type code names a symbol; an image is made when asked for */
@interface WsbsdIcon : NSObject { @public OSType type; } @end
@implementation WsbsdIcon @end
OSStatus GetIconRef(int16_t v, OSType creator, OSType type, IconRef *out)
{
	(void)v; if (!out) return paramErr; if (creator != kSystemIconsCreator) return -43;
	WsbsdIcon *i = [WsbsdIcon new]; i->type = type; *out = (IconRef)CFBridgingRetain(i); return noErr;
}
OSStatus ReleaseIconRef(IconRef r) { if (!r) return paramErr; CFRelease(r); return noErr; }
@implementation NSImage (WsbsdIconRef)
- (instancetype)initWithIconRef:(IconRef)ref
{
	WsbsdIcon *i = (__bridge WsbsdIcon *)ref; NSString *sym;
	switch (i ? i->type : 0) { case kAliasBadgeIcon: sym = @"arrow.turn.up.right"; break; case kLockedBadgeIcon: sym = @"lock.fill"; break; case kGenericFolderIcon: sym = @"folder.fill"; break; case kGenericDocumentIcon: sym = @"doc.fill"; break; default: sym = @"questionmark.square"; }
	NSImage *img = [NSImage imageWithSystemSymbolName: sym accessibilityDescription: nil]; if (img) return img; return [self initWithSize: NSMakeSize(16, 16)];
}
@end

/* URL scheme handlers: ~/Library/Preferences/org.wsbsd.launchservices.plist, scheme -> bundle identifier */
static NSString *HandlersPath(void) { const char *h = getenv("HOME"); return [[h ? [NSString stringWithUTF8String: h] : NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences"] stringByAppendingPathComponent: @"org.wsbsd.launchservices.plist"]; }
OSStatus LSSetDefaultHandlerForURLScheme(CFStringRef scheme, CFStringRef bundleID)
{
	if (!scheme || !bundleID) return paramErr; NSMutableDictionary *d = [[NSDictionary dictionaryWithContentsOfFile: HandlersPath()] mutableCopy] ?: [NSMutableDictionary dictionary];
	char s[256], b[256]; if (!CFStringGetCString(scheme, s, sizeof s, kCFStringEncodingUTF8) || !CFStringGetCString(bundleID, b, sizeof b, kCFStringEncodingUTF8)) return paramErr;
	d[[[NSString stringWithUTF8String: s] lowercaseString]] = [NSString stringWithUTF8String: b];
	[[NSFileManager defaultManager] createDirectoryAtPath: [HandlersPath() stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL];
	return [d writeToFile: HandlersPath() atomically: YES] ? noErr : -54;
}
CFStringRef LSCopyDefaultHandlerForURLScheme(CFStringRef scheme)
{
	char s[256]; if (!scheme || !CFStringGetCString(scheme, s, sizeof s, kCFStringEncodingUTF8)) return NULL;
	NSString *b = [NSDictionary dictionaryWithContentsOfFile: HandlersPath()][[[NSString stringWithUTF8String: s] lowercaseString]]; return b ? (CFStringRef)CFBridgingRetain(b) : NULL;
}

@implementation OSAScript (WsbsdFile)
- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSDictionary **)err
{
	NSString *src = [NSString stringWithContentsOfURL: url encoding: NSUTF8StringEncoding error: NULL];
	if (!src) { if (err) *err = @{ NSLocalizedDescriptionKey: @"The script could not be read." }; return nil; }              /* a compiled .scpt is not a text file: no scripting engine reads it */
	return [self initWithSource: src];
}
@end

@implementation NSCell (WsbsdAccessibilitySet)
- (void)accessibilitySetValue:(id)value forAttribute:(NSString *)attribute { (void)value; (void)attribute; }
@end
@implementation NSEvent (WsbsdSwipe)
+ (BOOL)isSwipeTrackingFromScrollEventsEnabled { return NO; }
- (void)trackSwipeEventWithOptions:(NSUInteger)o dampenAmountThresholdMin:(CGFloat)a max:(CGFloat)b usingHandler:(void (^)(CGFloat, NSUInteger, BOOL, BOOL *))h { (void)o; (void)a; (void)b; (void)h; }
@end

/* NSWorkspace's application lookup and the configuration-based open methods of macOS 10.15+, NSWorkspaceOpenConfiguration, NSApplication -activate, and
 * NSImage +imageWithSize:flipped:drawingHandler:. The lookup scans the application folders (/Applications, /System/Applications, ~/Applications, /usr/local/GNUstep/**) for bundles and
 * reads their CFBundleIdentifier and CFBundleDocumentTypes (extensions and UTIs), as LaunchServices' database holds them. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface NSWorkspaceOpenConfiguration : NSObject <NSCopying>
@property BOOL activates, addsToRecentItems, allowsRunningApplicationSubstitution, createsNewApplicationInstance, forPrinting, hides, hidesOthers, promptsUserIfNeeded, requiresUniversalLinks;
@property (copy) NSArray *arguments; @property (copy) NSDictionary *environment; @property (copy) NSAppleEventDescriptor *appleEvent; @property NSInteger architecture;
+ (instancetype)configuration;
@end
@implementation NSWorkspaceOpenConfiguration
@synthesize activates, addsToRecentItems, allowsRunningApplicationSubstitution, createsNewApplicationInstance, forPrinting, hides, hidesOthers, promptsUserIfNeeded, requiresUniversalLinks, arguments, environment, appleEvent, architecture;
+ (instancetype)configuration { NSWorkspaceOpenConfiguration *c = [[[self alloc] init] autorelease]; c.activates = YES; c.addsToRecentItems = YES; c.allowsRunningApplicationSubstitution = YES; c.promptsUserIfNeeded = YES; return c; }
- (id)copyWithZone:(NSZone *)z { NSWorkspaceOpenConfiguration *c = [[NSWorkspaceOpenConfiguration alloc] init]; c.activates = activates; c.addsToRecentItems = addsToRecentItems; c.allowsRunningApplicationSubstitution = allowsRunningApplicationSubstitution; c.createsNewApplicationInstance = createsNewApplicationInstance; c.forPrinting = forPrinting; c.hides = hides; c.hidesOthers = hidesOthers; c.promptsUserIfNeeded = promptsUserIfNeeded; c.requiresUniversalLinks = requiresUniversalLinks; c.arguments = arguments; c.environment = environment; c.architecture = architecture; return c; }
- (void)dealloc { [arguments release]; [environment release]; [appleEvent release]; [super dealloc]; }
@end

static NSArray *AppFolders(void)
{
	return [NSArray arrayWithObjects: @"/Applications", @"/System/Applications", @"/System/Applications/Utilities", @"/Applications/Utilities", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"], @"/usr/local/GNUstep/Local/Applications", @"/usr/local/GNUstep/System/Applications", @"/usr/GNUstep/Local/Applications", nil];
}
static NSDictionary *AppInfo(NSString *path)                      /* the bundle's property list: the macOS layout's, a flat one, or GNUstep's */
{
	for (NSString *rel in [NSArray arrayWithObjects: @"Contents/Info.plist", @"Info.plist", @"Resources/Info-gnustep.plist", @"Contents/Resources/Info-gnustep.plist", nil])
	{
		NSData *d = [NSData dataWithContentsOfFile: [path stringByAppendingPathComponent: rel]]; if (!d) continue;
		id pl = [NSPropertyListSerialization propertyListWithData: d options: 0 format: NULL error: NULL];
		if ([pl isKindOfClass: [NSDictionary class]]) return pl;
	}
	return nil;
}
/* every application bundle in the folders (one level of sub-folders deep), as {url, identifier, document types} */
static NSArray *Apps(void)
{
	static NSArray *cache; static NSTimeInterval at;
	if (cache && [NSDate timeIntervalSinceReferenceDate] - at < 5) return cache;
	NSMutableArray *out = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *dir in AppFolders())
		for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL])
		{
			if (![[n pathExtension] isEqual: @"app"]) continue;
			NSString *path = [dir stringByAppendingPathComponent: n];
			NSDictionary *info = AppInfo(path); if (!info) continue;
			[out addObject: [NSDictionary dictionaryWithObjectsAndKeys: [NSURL fileURLWithPath: path], @"url", [info objectForKey: @"CFBundleIdentifier"] ?: @"", @"id", [info objectForKey: @"CFBundleDocumentTypes"] ?: [NSArray array], @"types", nil]];
		}
	cache = [out retain]; at = [NSDate timeIntervalSinceReferenceDate]; return cache;
}
static BOOL AppHandles(NSDictionary *app, NSString *ext, NSString *uti, NSString *scheme)
{
	for (NSDictionary *t in [app objectForKey: @"types"])
	{
		for (NSString *e in [t objectForKey: @"CFBundleTypeExtensions"] ?: [NSArray array]) if (ext && ([e isEqual: @"*"] || [e caseInsensitiveCompare: ext] == NSOrderedSame)) return YES;
		for (NSString *u in [t objectForKey: @"LSItemContentTypes"] ?: [NSArray array]) if (uti && [u isEqual: uti]) return YES;
	}
	return NO;
}

@implementation NSWorkspace (WsdLaunchServices)
- (NSArray *)URLsForApplicationsWithBundleIdentifier:(NSString *)bid
{
	NSMutableArray *r = [NSMutableArray array]; for (NSDictionary *a in Apps()) if ([[a objectForKey: @"id"] isEqual: bid]) [r addObject: [a objectForKey: @"url"]]; return r;
}
- (NSURL *)URLForApplicationWithBundleIdentifier:(NSString *)bid { return [[self URLsForApplicationsWithBundleIdentifier: bid] firstObject]; }
- (NSArray *)URLsForApplicationsToOpenURL:(NSURL *)u
{
	NSMutableArray *r = [NSMutableArray array];
	NSString *ext = [u isFileURL] ? [[u path] pathExtension] : nil, *scheme = [u scheme];
	if (!ext && scheme) { for (NSDictionary *a in Apps()) { for (NSDictionary *t in [AppInfo([[a objectForKey: @"url"] path]) objectForKey: @"CFBundleURLTypes"] ?: [NSArray array]) if ([[t objectForKey: @"CFBundleURLSchemes"] containsObject: scheme]) { [r addObject: [a objectForKey: @"url"]]; break; } } return r; }
	if ([u isFileURL]) { BOOL dir = NO; if ([[NSFileManager defaultManager] fileExistsAtPath: [u path] isDirectory: &dir] && dir && ![[u path] hasSuffix: @".app"]) return [NSArray arrayWithObject: [NSURL fileURLWithPath: @"/System/Library/CoreServices/Finder.app"]]; }
	for (NSDictionary *a in Apps()) if (AppHandles(a, ext, nil, nil)) [r addObject: [a objectForKey: @"url"]];
	return r;
}
- (NSURL *)URLForApplicationToOpenURL:(NSURL *)u { return [[self URLsForApplicationsToOpenURL: u] firstObject]; }
- (NSArray *)URLsForApplicationsToOpenContentType:(id)type
{
	NSMutableArray *r = [NSMutableArray array]; NSString *uti = [type respondsToSelector: @selector(identifier)] ? [type performSelector: @selector(identifier)] : [type description];
	NSArray *exts = [type respondsToSelector: @selector(tags)] ? [[type performSelector: @selector(tags)] objectForKey: @"public.filename-extension"] : nil;
	for (NSDictionary *a in Apps()) { BOOL ok = AppHandles(a, nil, uti, nil); for (NSString *e in exts) ok = ok || AppHandles(a, e, nil, nil); if (ok) [r addObject: [a objectForKey: @"url"]]; }
	return r;
}
- (NSURL *)URLForApplicationToOpenContentType:(id)type { return [[self URLsForApplicationsToOpenContentType: type] firstObject]; }

- (void)openURL:(NSURL *)u configuration:(NSWorkspaceOpenConfiguration *)c completionHandler:(void (^)(NSRunningApplication *, NSError *))h
{
	BOOL ok = [self openURL: u]; NSError *e = ok ? nil : [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil];
	if (h) h(nil, e);
}
- (void)openURLs:(NSArray *)urls withApplicationAtURL:(NSURL *)app configuration:(NSWorkspaceOpenConfiguration *)c completionHandler:(void (^)(NSRunningApplication *, NSError *))h
{
	BOOL ok = YES; for (NSURL *u in urls) ok = [self openFile: [u path] withApplication: [[app path] lastPathComponent]] && ok;
	if (h) h(nil, ok ? nil : [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil]);
}
- (void)openApplicationAtURL:(NSURL *)app configuration:(NSWorkspaceOpenConfiguration *)c completionHandler:(void (^)(NSRunningApplication *, NSError *))h
{
	BOOL ok = [self launchApplication: [app path]]; if (h) h(nil, ok ? nil : [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil]);
}
- (BOOL)openURL:(NSURL *)u options:(NSUInteger)o configuration:(NSDictionary *)c error:(NSError **)err { BOOL ok = [self openURL: u]; if (!ok && err) *err = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil]; return ok; }
- (void)activateFileViewerSelectingURLs:(NSArray *)urls { for (NSURL *u in urls) [self selectFile: [u path] inFileViewerRootedAtPath: @""]; }
- (void)recycleURLs:(NSArray *)urls completionHandler:(void (^)(NSDictionary *, NSError *))h
{
	NSMutableDictionary *m = [NSMutableDictionary dictionary]; NSFileManager *fm = [NSFileManager defaultManager]; NSError *err = nil;
	NSString *trash = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; [fm createDirectoryAtPath: trash withIntermediateDirectories: YES attributes: nil error: NULL];
	for (NSURL *u in urls)
	{
		NSString *name = [[u path] lastPathComponent], *dst = [trash stringByAppendingPathComponent: name];
		for (int i = 2; [fm fileExistsAtPath: dst] && i < 1000; i++) dst = [trash stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %d.%@", [name stringByDeletingPathExtension], i, [name pathExtension]]];   /* a name taken in the Trash gets a number */
		if ([fm moveItemAtPath: [u path] toPath: dst error: &err]) [m setObject: [NSURL fileURLWithPath: dst] forKey: u];
	}
	if (h) h(m, err);
}
- (void)duplicateURLs:(NSArray *)urls completionHandler:(void (^)(NSDictionary *, NSError *))h
{
	NSMutableDictionary *m = [NSMutableDictionary dictionary]; NSFileManager *fm = [NSFileManager defaultManager]; NSError *err = nil;
	for (NSURL *u in urls)
	{
		NSString *base = [[u path] stringByDeletingPathExtension], *ext = [[u path] pathExtension]; NSString *dst = nil;
		for (int i = 0; i < 1000; i++) { NSString *n = i ? [NSString stringWithFormat: @"%@ copy %d", base, i + 1] : [base stringByAppendingString: @" copy"]; if ([ext length]) n = [n stringByAppendingPathExtension: ext]; if (![fm fileExistsAtPath: n]) { dst = n; break; } }
		if (dst && [fm copyItemAtPath: [u path] toPath: dst error: &err]) [m setObject: [NSURL fileURLWithPath: dst] forKey: u];
	}
	if (h) h(m, err);
}
- (BOOL)unmountAndEjectDeviceAtURL:(NSURL *)u error:(NSError **)err { BOOL ok = [self unmountAndEjectDeviceAtPath: [u path]]; if (!ok && err) *err = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: nil]; return ok; }
@end

@implementation NSApplication (WsdActivate)
- (void)activate { [self activateIgnoringOtherApps: YES]; }
@end

/* an image drawn by a block each time it is drawn (the block gets the rectangle of the image in the destination's coordinates) */
@interface WsdBlockImage : NSImage { BOOL _flip; BOOL (^_handler)(NSRect); } - (id)initWithSize:(NSSize)s flipped:(BOOL)f handler:(BOOL (^)(NSRect))h; @end
@implementation WsdBlockImage
- (id)initWithSize:(NSSize)s flipped:(BOOL)f handler:(BOOL (^)(NSRect))h { if ((self = [super initWithSize: s])) { _flip = f; _handler = [h copy]; } return self; }
- (void)wsdDrawIn:(NSRect)dst fraction:(CGFloat)f
{
	NSSize s = [self size]; if (s.width <= 0 || s.height <= 0) return;
	NSGraphicsContext *gc = [NSGraphicsContext currentContext]; [gc saveGraphicsState];
	NSAffineTransform *t = [NSAffineTransform transform];
	if (_flip) { [t translateXBy: dst.origin.x yBy: NSMaxY(dst)]; [t scaleXBy: dst.size.width / s.width yBy: -dst.size.height / s.height]; }
	else { [t translateXBy: dst.origin.x yBy: dst.origin.y]; [t scaleXBy: dst.size.width / s.width yBy: dst.size.height / s.height]; }
	[t concat]; [NSBezierPath clipRect: NSMakeRect(0, 0, s.width, s.height)];
	if (_handler) _handler(NSMakeRect(0, 0, s.width, s.height));
	[gc restoreGraphicsState];
}
- (void)drawInRect:(NSRect)r fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsdDrawIn: r fraction: f]; }
- (void)drawInRect:(NSRect)r { [self wsdDrawIn: r fraction: 1]; }
- (void)drawAtPoint:(NSPoint)p fromRect:(NSRect)from operation:(NSCompositingOperation)op fraction:(CGFloat)f { [self wsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: f]; }
- (void)compositeToPoint:(NSPoint)p operation:(NSCompositingOperation)op { [self wsdDrawIn: NSMakeRect(p.x, p.y, [self size].width, [self size].height) fraction: 1]; }
- (BOOL)isFlipped { return _flip; }
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (void)dealloc { [_handler release]; [super dealloc]; }
@end
@implementation NSImage (WsdBlock)
+ (NSImage *)imageWithSize:(NSSize)s flipped:(BOOL)f drawingHandler:(BOOL (^)(NSRect))h { return [[[WsdBlockImage alloc] initWithSize: s flipped: f handler: h] autorelease]; }
@end

/* a folder is opened by the Finder, as on the Mac: the running Finder is asked (distributed notification), else it is started on the folder */
static IMP origOpenFile, origOpenURL;
static BOOL WsdOpensInFinder(NSString *path)
{
	BOOL dir = NO; if (![path length] || ![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &dir] || !dir) return NO;
	NSString *ext = [[path pathExtension] lowercaseString]; if ([ext isEqual: @"app"] || [ext isEqual: @"framework"] || [ext isEqual: @"bundle"]) return NO;
	if ([[[NSProcessInfo processInfo] processName] isEqual: @"Finder"]) return NO;
	NSString *fin = @"/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"; BOOL running = NO;
	for (NSRunningApplication *a in [[NSWorkspace sharedWorkspace] runningApplications]) if ([[a bundleIdentifier] isEqual: @"com.apple.finder"]) running = YES;
	if (!running) { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: @"/bin/pgrep"]; [t setArguments: @[ @"-x", @"Finder" ]]; [t setStandardOutput: [NSFileHandle fileHandleWithNullDevice]]; @try { [t launch]; [t waitUntilExit]; running = [t terminationStatus] == 0; } @catch (NSException *e) {} }       /* a Finder that is not in a bundle */
	if (running) [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.finder.open" object: nil userInfo: @{ @"path": path } deliverImmediately: YES];
	else if ([[NSFileManager defaultManager] isExecutableFileAtPath: fin]) { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: fin]; NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy]; env[@"FINDER_PATH"] = path; env[@"FINDER_WINDOW"] = @"1"; [t setEnvironment: env]; @try { [t launch]; } @catch (NSException *e) { return NO; } }
	else return NO;
	return YES;
}
static BOOL wsdOpenFile(id self, SEL _cmd, NSString *f) { if (WsdOpensInFinder(f)) return YES; return ((BOOL (*)(id, SEL, id))origOpenFile)(self, _cmd, f); }
static BOOL wsdOpenURL(id self, SEL _cmd, NSURL *u) { if ([u isFileURL] && WsdOpensInFinder([u path])) return YES; return ((BOOL (*)(id, SEL, id))origOpenURL)(self, _cmd, u); }
@interface WsdOpenFolderInit : NSObject @end
@implementation WsdOpenFolderInit
+ (void)load
{
	Method f = class_getInstanceMethod([NSWorkspace class], @selector(openFile:)); if (f && !origOpenFile) origOpenFile = method_setImplementation(f, (IMP)wsdOpenFile);
	Method u = class_getInstanceMethod([NSWorkspace class], @selector(openURL:)); if (u && !origOpenURL) origOpenURL = method_setImplementation(u, (IMP)wsdOpenURL);
}
@end

/* NSWorkspace application lookup, open configuration, trash / duplicate, block-drawn images. */
#import <AppKit/AppKit.h>
@interface WsdCfg : NSObject + (instancetype)configuration; @property BOOL activates, createsNewApplicationInstance; @end
@interface NSWorkspace (D) - (NSURL *)URLForApplicationWithBundleIdentifier:(NSString *)b; - (NSArray *)URLsForApplicationsWithBundleIdentifier:(NSString *)b; - (void)duplicateURLs:(NSArray *)u completionHandler:(void (^)(NSDictionary *, NSError *))h; - (void)recycleURLs:(NSArray *)u completionHandler:(void (^)(NSDictionary *, NSError *))h; @end
@interface NSImage (D) + (NSImage *)imageWithSize:(NSSize)s flipped:(BOOL)f drawingHandler:(BOOL (^)(NSRect))h; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSString *root = [NSString stringWithFormat: @"%@/wsd-ws-test-%d", NSTemporaryDirectory(), getpid()]; NSString *home = NSHomeDirectory(); NSFileManager *fm = [NSFileManager defaultManager];
		NSString *app = [home stringByAppendingPathComponent: @"Applications/WsdTestFoo.app"]; [fm createDirectoryAtPath: root withIntermediateDirectories: YES attributes: nil error: NULL];
		[fm createDirectoryAtPath: [app stringByAppendingPathComponent: @"Contents"] withIntermediateDirectories: YES attributes: nil error: NULL];
		[@{ @"CFBundleIdentifier": @"org.wsd.foo", @"CFBundleName": @"Foo", @"CFBundleDocumentTypes": @[ @{ @"CFBundleTypeExtensions": @[ @"foo" ] } ] } writeToFile: [app stringByAppendingPathComponent: @"Contents/Info.plist"] atomically: YES];
		NSWorkspace *w = [NSWorkspace sharedWorkspace];
		NSURL *u = [w URLForApplicationWithBundleIdentifier: @"org.wsd.foo"];
		CHECK(u != nil); CHECK([[u path] hasSuffix: @"WsdTestFoo.app"]); CHECK([w URLForApplicationWithBundleIdentifier: @"no.such.app"] == nil);
		WsdCfg *c = [NSClassFromString(@"NSWorkspaceOpenConfiguration") configuration]; CHECK([c activates]); CHECK(![c createsNewApplicationInstance]);
		NSString *f = [root stringByAppendingPathComponent: @"a.txt"]; [@"x" writeToFile: f atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		__block NSDictionary *got = nil; [w duplicateURLs: @[ [NSURL fileURLWithPath: f] ] completionHandler: ^(NSDictionary *m, NSError *e) { got = m; }];
		CHECK([got count] == 1); CHECK([fm fileExistsAtPath: [root stringByAppendingPathComponent: @"a copy.txt"]]);
		__block int calls = 0; __block NSRect seen = NSZeroRect;
		NSImage *img = [NSImage imageWithSize: NSMakeSize(20, 10) flipped: YES drawingHandler: ^BOOL(NSRect r) { calls++; seen = r; return YES; }];
		CHECK(NSEqualSizes([img size], NSMakeSize(20, 10)));
		NSWindow *win = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 50, 50) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[[win contentView] lockFocus]; [img drawInRect: NSMakeRect(0, 0, 40, 20) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [[win contentView] unlockFocus];
		CHECK(calls == 1); CHECK(NSEqualRects(seen, NSMakeRect(0, 0, 20, 10)));
		__block NSDictionary *rec = nil; [w recycleURLs: @[ [NSURL fileURLWithPath: f] ] completionHandler: ^(NSDictionary *m, NSError *e) { rec = m; }];
		CHECK([rec count] == 1); CHECK(![fm fileExistsAtPath: f]); CHECK([fm fileExistsAtPath: [home stringByAppendingPathComponent: @".Trash/a.txt"]]);
		[fm removeItemAtPath: [home stringByAppendingPathComponent: @".Trash/a.txt"] error: NULL]; [fm removeItemAtPath: app error: NULL];
		[fm removeItemAtPath: root error: NULL];
	}
	printf(fails ? "workspace: %d failed\n" : "workspace ok\n", fails);
	return fails != 0;
}

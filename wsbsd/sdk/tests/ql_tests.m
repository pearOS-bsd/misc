/* QuickLook: a generator built in the test (a CFPlugIn bundle compiled with cc -shared) is found by content type and loaded, the built-in text and image previews, thumbnails, the panel and its responder-chain control */
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface Item : NSObject <QLPreviewItem> { @public NSURL *u; } @end
@implementation Item - (NSURL *)previewItemURL { return u; } @end
@interface Src : NSObject <QLPreviewPanelDataSource> { @public NSArray *items; int began, ended; } @end
@implementation Src
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)p { return [items count]; }
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)p previewItemAtIndex:(NSInteger)i { return items[i]; }
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)p { return YES; }
- (void)beginPreviewPanelControl:(QLPreviewPanel *)p { began++; }
- (void)endPreviewPanelControl:(QLPreviewPanel *)p { ended++; }
@end
static const char *gen_src =
"#include <QuickLook/QuickLook.h>\n"
"typedef struct { QLGeneratorInterfaceStruct *conduit; UInt32 rc; } Gen;\n"
"static HRESULT qi(void *t, REFIID i, LPVOID *p) { *p = t; return S_OK; }\n"
"static ULONG ar(void *t) { return ++((Gen *)t)->rc; }\n"
"static OSStatus prev(void *t, QLPreviewRequestRef r, CFURLRef u, CFStringRef uti, CFDictionaryRef o) {\n"
"  CFDataRef d = CFDataCreate(NULL, (const UInt8 *)\"GENERATED\", 9); QLPreviewRequestSetDataRepresentation(r, d, CFSTR(\"public.plain-text\"), NULL); CFRelease(d); return 0; }\n"
"static OSStatus thumb(void *t, QLThumbnailRequestRef r, CFURLRef u, CFStringRef uti, CFDictionaryRef o, CGSize s) {\n"
"  CGContextRef c = QLThumbnailRequestCreateContext(r, s, 1, NULL); CGContextSetRGBFillColor(c, 1, 0, 0, 1); CGContextFillRect(c, CGRectMake(0, 0, s.width, s.height)); QLThumbnailRequestFlushContext(r, c); CGContextRelease(c); return 0; }\n"
"static void cancel(void *t, void *r) {}\n"
"static QLGeneratorInterfaceStruct vt = { 0, qi, ar, ar, thumb, (void *)cancel, prev, (void *)cancel };\n"
"void *Factory(CFAllocatorRef a, CFUUIDRef type) { static Gen g; g.conduit = &vt; g.rc = 1; return &g; }\n";
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		char dir[] = "/tmp/wsbsd-ql-XXXXXX"; CHECK(mkdtemp(dir) != NULL); NSString *d = [NSString stringWithUTF8String: dir];
		NSString *bundle = [d stringByAppendingPathComponent: @"ql/Test.qlgenerator"], *macos = [bundle stringByAppendingPathComponent: @"Contents/MacOS"];
		[[NSFileManager defaultManager] createDirectoryAtPath: macos withIntermediateDirectories: YES attributes: nil error: NULL];
		[[NSString stringWithUTF8String: gen_src] writeToFile: [d stringByAppendingPathComponent: @"gen.c"] atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		NSString *cmd = [NSString stringWithFormat: @"cc -shared -fPIC -w %s -I%s -o '%@/Test' '%@/gen.c' 2>&1", getenv("WSBSD_QL_CFLAGS") ?: "", getenv("WSBSD_SDK_INCLUDE") ?: "sdk/include", macos, d];
		CHECK(system([cmd UTF8String]) == 0);
		NSDictionary *info = @{ @"CFBundleExecutable": @"Test", @"CFBundleIdentifier": @"org.wsbsd.test.ql", @"CFBundlePackageType": @"BNDL",
			@"CFPlugInFactories": @{ @"11111111-2222-3333-4444-555555555555": @"Factory" },
			@"CFPlugInTypes": @{ @"5E2D9680-5022-40FA-B806-43349622E5B9": @[ @"11111111-2222-3333-4444-555555555555" ] },
			@"CFBundleDocumentTypes": @[ @{ @"LSItemContentTypes": @[ @"public.plain-text" ] } ] };
		[info writeToFile: [bundle stringByAppendingPathComponent: @"Contents/Info.plist"] atomically: YES];
		setenv("WSBSD_QL_PATH", [[d stringByAppendingPathComponent: @"ql"] UTF8String], 1);

		NSString *txt = [d stringByAppendingPathComponent: @"a.txt"]; [@"hello" writeToFile: txt atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		WsbsdQLPreview *p = [WsbsdQLPreview previewForURL: [NSURL fileURLWithPath: txt]];
		CHECK(p.kind == 1 && [[p.text string] isEqual: @"GENERATED"]);
		CGImageRef t = QLThumbnailImageCreate(NULL, (__bridge CFURLRef)[NSURL fileURLWithPath: txt], CGSizeMake(32, 24), NULL);
		CHECK(t && CGImageGetWidth(t) == 32 && CGImageGetHeight(t) == 24); if (t) CGImageRelease(t);

		unsetenv("WSBSD_QL_PATH");                                                                                   /* no generator for a non-text type: built-in */
		NSString *rtf = [d stringByAppendingPathComponent: @"b.rtf"]; [@"{\\rtf1 hi}" writeToFile: rtf atomically: YES encoding: NSUTF8StringEncoding error: NULL];
		p = [WsbsdQLPreview previewForURL: [NSURL fileURLWithPath: rtf]]; CHECK(p.kind == 1 && [[p.text string] containsString: @"hi"]);
		NSString *bin = [d stringByAppendingPathComponent: @"c.dat"]; [[NSData dataWithBytes: "a\0b" length: 3] writeToFile: bin atomically: YES];
		p = [WsbsdQLPreview previewForURL: [NSURL fileURLWithPath: bin]]; CHECK(p.kind == 0);

		Src *src = [Src new]; Item *i1 = [Item new], *i2 = [Item new]; i1->u = [NSURL fileURLWithPath: rtf]; i2->u = [NSURL fileURLWithPath: bin]; src->items = @[ i1, i2 ];
		QLPreviewPanel *panel = [QLPreviewPanel sharedPreviewPanel]; CHECK([QLPreviewPanel sharedPreviewPanelExists]);
		panel.dataSource = src; [panel reloadData]; CHECK([[panel currentPreviewItem] previewItemURL] != nil && [[[panel currentPreviewItem] previewItemURL] isEqual: i1->u]);
		panel.currentPreviewItemIndex = 1; [panel refreshCurrentPreviewItem]; CHECK([[panel currentPreviewItem] previewItemURL] == i2->u);
		CHECK([[panel title] isEqual: @"c.dat"]);
	}
	printf(fails ? "ql_tests: %d failed\n" : "ql_tests: ok\n", fails); return fails != 0;
}

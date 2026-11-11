/* test_nsfilepromiseprovider.m — behaviour checks for NSFilePromiseProvider core */
#import "../src/NSFilePromiseProvider.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Dele : NSObject <NSFilePromiseProviderDelegate> @end
@implementation Dele
- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)p fileNameForType:(NSString *)t { return @"out.txt"; }
- (void)filePromiseProvider:(NSFilePromiseProvider *)p writePromiseToURL:(NSURL *)u completionHandler:(void (^)(NSError *))h { h(nil); }
@end

int main(void) {
    @autoreleasepool {
        Dele *d = [Dele new];
        NSFilePromiseProvider *p = [[NSFilePromiseProvider alloc] initWithFileType:@"public.plain-text" delegate:d];
        CHECK([p.fileType isEqual:@"public.plain-text"], "fileType stored");
        CHECK(p.delegate == d, "delegate stored (weak)");
        CHECK(p.userInfo == nil, "userInfo nil");

        /* writableTypesForPasteboard: fixed 5-UTI order (measured) */
        NSPasteboard *noPb = nil;
        NSArray *types = [p writableTypesForPasteboard:noPb];
        CHECK(types.count == 5, "five writable types");
        CHECK([types[0] isEqual:@"com.apple.NSFilePromiseItemMetaData"], "type[0] metadata");
        CHECK([types[1] isEqual:@"com.apple.pasteboard.promised-file-name"], "type[1] promised-file-name");
        CHECK([types[2] isEqual:@"com.apple.pasteboard.promised-suggested-file-name"], "type[2] suggested-file-name");
        CHECK([types[3] isEqual:@"com.apple.pasteboard.promised-file-content-type"], "type[3] content-type");
        CHECK([types[4] isEqual:@"com.apple.pasteboard.NSFilePromiseID"], "type[4] promise id");

        /* value setters */
        p.fileType = @"public.png";
        CHECK([p.fileType isEqual:@"public.png"], "fileType setter");
        p.userInfo = @{@"k": @"v"};
        CHECK([p.userInfo[@"k"] isEqual:@"v"], "userInfo setter");

        /* alternateFileTypes copy */
        NSMutableArray *alt = [@[@"public.jpeg"] mutableCopy];
        p.alternateFileTypes = alt;
        [alt addObject:@"public.tiff"];
        CHECK(p.alternateFileTypes.count == 1, "alternateFileTypes snapshot-copied");

        /* stage2 provisioning is safe/nil */
        CHECK([p pasteboardPropertyListForType:@"com.apple.pasteboard.promised-file-name"] == nil, "pasteboardPropertyListForType stage2 nil");
        CHECK([p writingOptionsForType:@"x" pasteboard:noPb] == 0, "writingOptionsForType stage2 0");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}

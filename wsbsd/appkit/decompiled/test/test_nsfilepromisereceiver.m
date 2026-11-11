/* test_nsfilepromisereceiver.m — behaviour checks for NSFilePromiseReceiver core */
#import "../src/NSFilePromiseReceiver.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* readable drag types (measured fixed order) */
        NSArray *t = [NSFilePromiseReceiver readableDraggedTypes];
        CHECK(t.count == 3, "three readable dragged types");
        CHECK([t[0] isEqual:@"com.apple.NSFilePromiseItemMetaData"], "type[0] metadata");
        CHECK([t[1] hasPrefix:@"dyn."], "type[1] dynamic promised-file-url UTI");
        CHECK([t[2] isEqual:@"com.apple.pasteboard.promised-file-content-type"], "type[2] content-type");

        NSPasteboard *noPb = nil;
        NSArray *t2 = [NSFilePromiseReceiver readableTypesForPasteboard:noPb];
        CHECK([t2 isEqualToArray:t], "readableTypesForPasteboard matches readableDraggedTypes");
        CHECK([NSFilePromiseReceiver readingOptionsForType:@"com.apple.pasteboard.promised-file-content-type" pasteboard:noPb] == 2,
              "readingOptions AsPropertyList (2)");

        /* NSPasteboardReading init stores the plist; fileTypes/fileNames stage2 empty */
        NSFilePromiseReceiver *r = [[NSFilePromiseReceiver alloc] initWithPasteboardPropertyList:@{@"uti": @"public.png"}
                                                                                         ofType:@"com.apple.pasteboard.promised-file-content-type"];
        CHECK(r != nil, "initWithPasteboardPropertyList returns an object");
        CHECK(r.fileTypes.count == 0 && r.fileNames.count == 0, "fileTypes/fileNames stage2 empty");

        /* receivePromisedFiles... is a safe stage2 no-op */
        NSURL *dir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        __block BOOL readerCalled = NO;
        [r receivePromisedFilesAtDestination:dir options:@{} operationQueue:(id)[NSObject new]
                                      reader:^(NSURL *u, NSError *e) { readerCalled = YES; }];
        CHECK(!readerCalled, "reader not called in stage2 core (no fetch)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}

/* NSDocument additions: duplicate through the document's own read / write, lock flag, move, backup URL, completion-handler save, class defaults. */
#import <AppKit/AppKit.h>
@interface NSDocument (D) + (BOOL)autosavesInPlace; - (NSDocument *)duplicateAndReturnError:(NSError **)e; - (BOOL)isLocked; - (void)lockWithCompletionHandler:(void (^)(NSError *))h; - (void)unlockWithCompletionHandler:(void (^)(NSError *))h;
- (void)moveToURL:(NSURL *)u completionHandler:(void (^)(NSError *))h; - (NSURL *)backupFileURL; - (void)saveToURL:(NSURL *)u ofType:(NSString *)t forSaveOperation:(NSSaveOperationType)op completionHandler:(void (^)(NSError *))h; - (BOOL)isDraft; - (void)setDraft:(BOOL)b; @end
@interface Doc : NSDocument { @public NSString *text; } @end
@implementation Doc
+ (NSArray *)readableTypes { return @[ @"txt" ]; } + (NSArray *)writableTypes { return @[ @"txt" ]; }
- (BOOL)writeToURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e { return [text writeToURL: u atomically: YES encoding: NSUTF8StringEncoding error: e]; }
- (BOOL)readFromURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e { text = [NSString stringWithContentsOfURL: u encoding: NSUTF8StringEncoding error: e]; return text != nil; }
- (void)makeWindowControllers {}
@end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		CHECK(![Doc autosavesInPlace]);
		NSString *dir = [NSString stringWithFormat: @"%@/wsd-doc-%d", NSTemporaryDirectory(), getpid()]; NSFileManager *fm = [NSFileManager defaultManager]; [fm createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
		Doc *d = [[Doc alloc] init]; d->text = @"hello"; [d setFileType: @"txt"]; NSURL *u = [NSURL fileURLWithPath: [dir stringByAppendingPathComponent: @"a.txt"]];
		__block NSError *err = nil; [d saveToURL: u ofType: @"txt" forSaveOperation: NSSaveToOperation completionHandler: ^(NSError *e) { err = e; }];
		CHECK(err == nil); CHECK([fm fileExistsAtPath: [u path]]);
		[d setFileURL: u];
		Doc *c = (Doc *)[d duplicateAndReturnError: &err]; CHECK(c != nil); CHECK([c->text isEqual: @"hello"]); CHECK([c fileURL] == nil); CHECK([[c displayName] hasSuffix: @"copy"]);
		CHECK(![d isLocked]); [d lockWithCompletionHandler: nil]; CHECK([d isLocked]); [d unlockWithCompletionHandler: nil]; CHECK(![d isLocked]);
		CHECK([[[d backupFileURL] lastPathComponent] isEqual: @".~a.txt"]);
		NSURL *u2 = [NSURL fileURLWithPath: [dir stringByAppendingPathComponent: @"b.txt"]]; [d moveToURL: u2 completionHandler: ^(NSError *e) { err = e; }];
		CHECK(err == nil); CHECK([[d fileURL] isEqual: u2]); CHECK([fm fileExistsAtPath: [u2 path]]); CHECK(![fm fileExistsAtPath: [u path]]);
		CHECK(![d isDraft]); [d setDraft: YES]; CHECK([d isDraft]);
		[fm removeItemAtPath: dir error: NULL];
	}
	printf(fails ? "document: %d failed\n" : "document ok\n", fails);
	return fails != 0;
}

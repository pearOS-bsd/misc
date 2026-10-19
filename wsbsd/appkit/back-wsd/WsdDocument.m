/* NSDocument methods of macOS 10.7+ that GNUstep lacks: duplicate / rename / move, lock and unlock (the file's user-immutable flag), drafts, autosaving (autosavesInPlace and the timer that calls
 * autosaveDocumentWithDelegate:), the completion-handler save, change-count tokens, display name override, presented item URL. Document classes answer NO to +autosavesInPlace /
 * +autosavesDrafts / +preservesVersions / +canConcurrentlyReadDocumentsOfType: unless they override them (as on macOS). Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <sys/stat.h>

static char kDraft, kName, kTimer, kTokens;

@interface NSDocument (WsdDocumentPrivate) @end
@implementation NSDocument (WsdDocument)
+ (BOOL)autosavesInPlace { return NO; }
+ (BOOL)autosavesDrafts { return NO; }
+ (BOOL)preservesVersions { return [self autosavesInPlace]; }
+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)t { return NO; }
+ (BOOL)usesUbiquitousStorage { return NO; }
- (BOOL)isInViewingMode { return NO; }
- (BOOL)isEntireFileLoaded { return YES; }
- (BOOL)savePanelShowsFileFormatsControl { return [[[self class] writableTypes] count] > 1; }
- (BOOL)allowsDocumentSharing { return [self fileURL] != nil; }
- (BOOL)isDraft { return [objc_getAssociatedObject(self, &kDraft) boolValue]; }
- (void)setDraft:(BOOL)b { objc_setAssociatedObject(self, &kDraft, [NSNumber numberWithBool: b], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)defaultDraftName { return @"Untitled"; }
- (NSURL *)presentedItemURL { return [self fileURL]; }
- (BOOL)isLocked { NSURL *u = [self fileURL]; struct stat st; return u && stat([[u path] fileSystemRepresentation], &st) == 0 && (st.st_flags & UF_IMMUTABLE); }
- (BOOL)wsdSetLocked:(BOOL)lock error:(NSError **)err
{
	NSURL *u = [self fileURL]; if (!u) return NO;
	struct stat st; const char *p = [[u path] fileSystemRepresentation]; if (stat(p, &st) != 0) return NO;
	u_long fl = lock ? (st.st_flags | UF_IMMUTABLE) : (st.st_flags & ~UF_IMMUTABLE);
	if (chflags(p, fl) != 0) { if (err) *err = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]; return NO; }
	return YES;
}
- (void)lockDocument:(id)s { [self wsdSetLocked: YES error: NULL]; }
- (void)unlockDocument:(id)s { [self wsdSetLocked: NO error: NULL]; }
- (void)lockWithCompletionHandler:(void (^)(NSError *))h { NSError *e = nil; [self wsdSetLocked: YES error: &e]; if (h) h(e); }
- (void)unlockWithCompletionHandler:(void (^)(NSError *))h { NSError *e = nil; [self wsdSetLocked: NO error: &e]; if (h) h(e); }
- (void)lockDocumentWithCompletionHandler:(void (^)(BOOL))h { BOOL ok = [self wsdSetLocked: YES error: NULL]; if (h) h(ok); }
- (void)unlockDocumentWithCompletionHandler:(void (^)(BOOL))h { BOOL ok = [self wsdSetLocked: NO error: NULL]; if (h) h(ok); }

- (NSURL *)backupFileURL
{
	NSURL *u = [self fileURL]; if (!u) return nil;
	NSString *p = [[u path] stringByDeletingLastPathComponent], *n = [[u path] lastPathComponent];
	return [NSURL fileURLWithPath: [p stringByAppendingPathComponent: [@".~" stringByAppendingString: n]]];
}

/* a copy of the document: its contents written and read again through the document's own methods, untitled, with "copy" in its name */
- (NSDocument *)duplicateAndReturnError:(NSError **)err
{
	NSString *type = [self fileType]; NSError *e = nil;
	NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"wsd-dup-%d-%lu", (int)getpid(), (unsigned long)[self hash]]];
	NSURL *t = [NSURL fileURLWithPath: tmp];
	if (![self writeToURL: t ofType: type error: &e]) { if (err) *err = e; return nil; }
	NSDocument *d = [[[[self class] alloc] init] autorelease];
	BOOL ok = [d readFromURL: t ofType: type error: &e];
	[[NSFileManager defaultManager] removeItemAtPath: tmp error: NULL];
	if (!ok) { if (err) *err = e; return nil; }
	[d setFileType: type]; [d setDisplayName: [[self displayName] stringByAppendingString: @" copy"]]; [d setFileURL: nil];
	NSDocumentController *dc = [NSDocumentController sharedDocumentController];
	[dc addDocument: d]; [d makeWindowControllers]; [d showWindows];
	return d;
}
- (void)duplicateDocument:(id)s { NSError *e = nil; if (![self duplicateAndReturnError: &e] && e) [self presentError: e]; }
- (void)duplicateDocumentWithDelegate:(id)delegate didDuplicateSelector:(SEL)sel contextInfo:(void *)ctx
{
	NSDocument *d = [self duplicateAndReturnError: NULL];
	if (delegate && sel) ((void (*)(id, SEL, id, BOOL, void *))objc_msgSend)(delegate, sel, self, d != nil, ctx);
}

- (void)moveToURL:(NSURL *)url completionHandler:(void (^)(NSError *))h
{
	NSError *e = nil; NSURL *old = [self fileURL];
	if (old && ![[NSFileManager defaultManager] moveItemAtURL: old toURL: url error: &e]) { if (h) h(e); return; }
	[self setFileURL: url]; if (h) h(nil);
}
- (void)moveDocumentWithCompletionHandler:(void (^)(BOOL))h
{
	NSSavePanel *p = [NSSavePanel savePanel]; if ([self fileURL]) { [p setDirectoryURL: [[self fileURL] URLByDeletingLastPathComponent]]; [p setNameFieldStringValue: [[self fileURL] lastPathComponent]]; }
	if ([p runModal] != NSModalResponseOK) { if (h) h(NO); return; }
	[self moveToURL: [p URL] completionHandler: ^(NSError *e) { if (h) h(e == nil); }];
}
- (void)moveDocument:(id)s { [self moveDocumentWithCompletionHandler: nil]; }
- (void)renameDocument:(id)s
{
	NSURL *u = [self fileURL]; if (!u) return;
	NSAlert *a = [[[NSAlert alloc] init] autorelease]; [a setMessageText: @"Rename"]; [a addButtonWithTitle: @"Rename"]; [a addButtonWithTitle: @"Cancel"];
	NSTextField *f = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 240, 24)] autorelease]; [f setStringValue: [[u path] lastPathComponent]]; [a setAccessoryView: f];
	if ([a runModal] != NSAlertFirstButtonReturn || ![[f stringValue] length]) return;
	[self moveToURL: [[u URLByDeletingLastPathComponent] URLByAppendingPathComponent: [f stringValue]] completionHandler: nil];
}

- (void)setDisplayName:(NSString *)n { objc_setAssociatedObject(self, &kName, n, OBJC_ASSOCIATION_COPY_NONATOMIC); }

/* autosaving */
- (void)scheduleAutosaving
{
	NSTimeInterval iv = [[NSDocumentController sharedDocumentController] autosavingDelay]; if (iv <= 0) iv = 30;
	NSTimer *old = objc_getAssociatedObject(self, &kTimer); [old invalidate];
	NSTimer *t = [NSTimer scheduledTimerWithTimeInterval: iv target: self selector: @selector(wsdAutosaveFired:) userInfo: nil repeats: NO];
	objc_setAssociatedObject(self, &kTimer, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)wsdAutosaveFired:(NSTimer *)t { objc_setAssociatedObject(self, &kTimer, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); if ([self hasUnautosavedChanges]) [self autosaveDocumentWithDelegate: nil didAutosaveSelector: NULL contextInfo: NULL]; }
- (void)autosaveWithImplicitCancellability:(BOOL)c completionHandler:(void (^)(NSError *))h
{
	NSURL *u = [self fileURL]; NSError *e = nil;
	if (u) [self saveToURL: u ofType: [self fileType] forSaveOperation: NSAutosaveOperation error: &e];
	if (h) h(e);
}
- (BOOL)autosavingIsImplicitlyCancellable { return NO; }
- (BOOL)checkAutosavingSafetyAndReturnError:(NSError **)err { return YES; }
- (void)saveToURL:(NSURL *)url ofType:(NSString *)type forSaveOperation:(NSSaveOperationType)op completionHandler:(void (^)(NSError *))h
{
	NSError *e = nil; [self saveToURL: url ofType: type forSaveOperation: op error: &e]; if (h) h(e);
}
- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)u ofType:(NSString *)t forSaveOperation:(NSSaveOperationType)op { return NO; }
- (id)changeCountTokenForSaveOperation:(NSSaveOperationType)op { return [NSNumber numberWithInteger: [objc_getAssociatedObject(self, &kTokens) integerValue]]; }
- (void)updateChangeCountWithToken:(id)tok forSaveOperation:(NSSaveOperationType)op { [self updateChangeCount: NSChangeCleared]; }
- (void)performActivityWithSynchronousWaiting:(BOOL)w usingBlock:(void (^)(void (^)(void)))b { b(^{}); }
- (void)continueAsynchronousWorkOnMainThreadUsingBlock:(void (^)(void))b { b(); }
- (void)unblockUserInteraction {}
- (NSError *)willNotPresentError:(NSError *)e { return e; }
- (BOOL)isBrowsingVersions { return NO; }
- (void)invalidateRestorableState {}
@end

/* -setDisplayName: gives the document a name that -displayName answers (until the document has a file) */
static IMP origDisplayName;
static NSString *wsdDisplayName(NSDocument *self, SEL _cmd)
{
	NSString *n = objc_getAssociatedObject(self, &kName);
	if (n && ![self fileURL]) return n;
	return ((NSString *(*)(id, SEL))origDisplayName)(self, _cmd);
}
@interface WsdDocumentInit : NSObject @end
@implementation WsdDocumentInit
+ (void)load { Method m = class_getInstanceMethod([NSDocument class], @selector(displayName)); if (m) { origDisplayName = method_getImplementation(m); class_replaceMethod([NSDocument class], @selector(displayName), (IMP)wsdDisplayName, method_getTypeEncoding(m)); } }
@end

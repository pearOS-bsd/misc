/* OpenDocument.m — NSWindowController (nib-driven windows), NSDocument creation/showing and NSDocumentController: untitled and opened documents, as far as a document-based app needs at launch */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSDocument.h"
#import "NSDocumentController.h"
#import "NSWindowController.h"
#import "OpenFilePanels.h"
#import "NSMenuItem.h"
#import "NSSavePanel.h"
#import "NSScrollView.h"
#import "NSScroller.h"

@interface NSBundle (OpenNibDecl2) - (BOOL)loadNibNamed:(NSString *)n owner:(id)o topLevelObjects:(NSArray **)t; @end
static char kNibName, kNibOwner, kLoaded;

@implementation NSWindowController (OpenNib)
- (instancetype)initWithWindowNibName:(NSString *)n { return [self initWithWindowNibName:n owner:self]; }
- (instancetype)initWithWindowNibName:(NSString *)n owner:(id)o
{
    self = [self initWithWindow:nil];
    objc_setAssociatedObject(self, &kNibName, n, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(self, &kNibOwner, o, OBJC_ASSOCIATION_ASSIGN);
    return self;
}
- (NSString *)windowNibName { return objc_getAssociatedObject(self, &kNibName); }
- (id)owner { return objc_getAssociatedObject(self, &kNibOwner) ?: self; }
- (void)loadWindow
{
    if ([objc_getAssociatedObject(self, &kLoaded) boolValue]) return;
    objc_setAssociatedObject(self, &kLoaded, @YES, OBJC_ASSOCIATION_RETAIN);
    NSString *n = [self windowNibName]; if (!n) return;
    [self windowWillLoad];
    NSArray *top = nil; [[NSBundle mainBundle] loadNibNamed:n owner:[self owner] topLevelObjects:&top];
    if (![self valueForKey:@"window"]) for (id o in top) if ([o isKindOfClass:[NSWindow class]]) { [self setValue:o forKey:@"window"]; break; }		/* the window outlet is on the owner (the document), not on the controller: the first window of the nib is the one */
    if (![self valueForKey:@"window"] && [[self owner] respondsToSelector:@selector(window)]) { id w = [[self owner] performSelector:@selector(window)]; if (w && w != (id)self) [self setValue:w forKey:@"window"]; }
    if (getenv("OPEN_DEBUG")) { id o = [self owner]; fprintf(stderr, "open: loaded %s: owner %s window=%p wcs=%lu sticky=%p\n", [n UTF8String], class_getName([o class]), (__bridge void *)[self valueForKey:@"window"], (unsigned long)[[o respondsToSelector:@selector(windowControllers)] ? [o windowControllers] : @[] count], [o respondsToSelector:NSSelectorFromString(@"stickyWindow")] ? (__bridge void *)[o valueForKey:@"stickyWindow"] : NULL); }
    { id d = [self valueForKey:@"document"]; if ([d respondsToSelector:@selector(windowControllerDidLoadNib:)]) [d performSelector:@selector(windowControllerDidLoadNib:) withObject:self]; }		/* the document learns that its nib is loaded */
    { NSWindow *lw = [self valueForKey:@"window"]; if (lw) [lw performSelector:NSSelectorFromString(@"setWindowController:") withObject:self]; }
    [self windowDidLoad];
}
- (NSWindow *)window { [self loadWindow]; return [self valueForKey:@"_window"]; }			/* the window of a controller with a nib is loaded when it is asked for (as AppKit does) */
- (void)windowWillLoad { }
- (void)windowDidLoad { }
- (BOOL)isWindowLoaded { return [objc_getAssociatedObject(self, &kLoaded) boolValue] || [self windowNibName] == nil; }
- (void)showWindow:(id)sender { [self loadWindow]; NSWindow *w = [self valueForKey:@"window"]; if (w) [w performSelector:NSSelectorFromString(@"setWindowController:") withObject:self]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: showWindow: %s window %p\n", class_getName([self class]), (__bridge void *)w); if (w && ![[w title] length]) { id doc = [self valueForKey:@"document"]; NSString *t = doc ? [doc displayName] : nil; if ([t length]) [w setTitle:t]; }
    [w makeKeyAndOrderFront:sender]; }
@end

@implementation NSDocument (OpenCreate)
- (instancetype)initWithType:(NSString *)t error:(NSError **)e { if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: initWithType %s\n", [t UTF8String]); self = [self init]; if (self) [self setValue:t forKey:@"fileType"]; return self; }
- (instancetype)initWithContentsOfURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e
{
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: initWithContentsOfURL ofType %s\n", [t UTF8String]);
    self = [self init]; if (!self) return nil;
    BOOL ok = [self readFromURL:u ofType:t error:e];
    if (!ok) return nil;
    [self setValue:u forKey:@"fileURL"]; [self setValue:t forKey:@"fileType"];
    return self;
}
- (BOOL)readFromURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e
{
    NSData *d = [NSData dataWithContentsOfURL:u]; if (!d) return NO;
    return [self readFromData:d ofType:t error:e];
}
- (BOOL)readFromData:(NSData *)d ofType:(NSString *)t error:(NSError **)e { return NO; }
- (NSString *)windowNibName { return nil; }
- (void)makeWindowControllers
{
    NSString *n = [self windowNibName]; if (!n) return;
    NSWindowController *wc = [[NSWindowController alloc] initWithWindowNibName:n owner:self];
    [self addWindowController:wc];
}
- (void)showWindows { if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: showWindows: %lu controllers\n", (unsigned long)[[self windowControllers] count]); for (NSWindowController *wc in [self windowControllers]) [wc showWindow:self]; }
- (NSArray *)windowControllers { return [self valueForKey:@"_windowControllers"] ?: @[]; }
@end

@implementation NSDocumentController (OpenCreate)
- (NSDictionary *)_openTypeForExtension:(NSString *)ext
{
    NSArray *types = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
    for (NSDictionary *t in types) { NSArray *exts = t[@"CFBundleTypeExtensions"]; if (!ext || [exts containsObject:ext]) return t; }
    return [types firstObject];
}
- (NSDictionary *)_openTypeForURL:(NSURL *)u
{
    NSString *ext = [[u pathExtension] lowercaseString], *uti = nil;
    static NSDictionary *map; if (!map) map = @{ @"txt": @"public.plain-text", @"text": @"public.plain-text", @"rtf": @"public.rtf", @"rtfd": @"com.apple.rtfd", @"html": @"public.html", @"htm": @"public.html", @"doc": @"com.microsoft.word.doc", @"docx": @"org.openxmlformats.wordprocessingml.document", @"odt": @"org.oasis-open.opendocument.text", @"md": @"public.plain-text" };
    @try { id v = nil; [u getResourceValue:&v forKey:NSURLTypeIdentifierKey error:nil]; uti = v; } @catch (id x) { }
    if (map[ext]) uti = map[ext]; else if (!uti || [uti hasPrefix:@"dyn."]) uti = ext.length ? nil : @"public.plain-text";
    NSArray *types = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"];
    if (uti) for (NSDictionary *t in types) if ([t[@"LSItemContentTypes"] containsObject:uti]) { NSMutableDictionary *m = [t mutableCopy]; m[@"_openUTI"] = uti; return m; }
    return [self _openTypeForExtension:ext];
}
- (Class)_openClassFor:(NSDictionary *)t
{
    NSString *n = t[@"NSDocumentClass"]; if (!n) return Nil;
    Class k = NSClassFromString(n);
    if (!k) { NSString *exe = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"]; k = NSClassFromString([NSString stringWithFormat:@"%@.%@", exe, n]); }
    if (!k) fprintf(stderr, "open: document class %s not found\n", [n UTF8String]);
    return k;
}
- (id)openUntitledDocumentAndDisplay:(BOOL)display error:(NSError **)e
{
    NSDictionary *t = [self _openTypeForExtension:nil]; Class k = [self _openClassFor:t]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: openUntitled: class %s\n", k ? class_getName(k) : "nil"); if (!k) return nil;
    NSDocument *doc = [[k alloc] initWithType:([t[@"LSItemContentTypes"] firstObject] ?: t[@"CFBundleTypeName"] ?: @"") error:e]; if (!doc) return nil;
    [self addDocument:doc]; [doc makeWindowControllers]; if (display) [doc showWindows];
    return doc;
}
- (id)openDocumentWithContentsOfURL:(NSURL *)u display:(BOOL)display error:(NSError **)e
{
    NSDictionary *t = [self _openTypeForURL:u]; Class k = [self _openClassFor:t]; if (!k) return nil;
    NSDocument *doc = [[k alloc] initWithContentsOfURL:u ofType:(t[@"_openUTI"] ?: [t[@"LSItemContentTypes"] firstObject] ?: t[@"CFBundleTypeName"] ?: @"") error:e]; if (!doc) return nil;
    [self addDocument:doc]; [doc makeWindowControllers]; if (display) [doc showWindows];
    return doc;
}
@end

@implementation NSDocument (OpenUndo)
static char kUM;
- (NSUndoManager *)undoManager { NSUndoManager *u = objc_getAssociatedObject(self, &kUM); if (!u) { u = [NSUndoManager new]; objc_setAssociatedObject(self, &kUM, u, OBJC_ASSOCIATION_RETAIN); } return u; }
- (void)setUndoManager:(NSUndoManager *)u { objc_setAssociatedObject(self, &kUM, u, OBJC_ASSOCIATION_RETAIN); }
- (BOOL)hasUndoManager { return YES; }
@end

/* ---- window geometry the programs ask for (the frame includes the title bar of 32 pt for titled windows) ---- */
@interface NSWindow (OpenGeom) - (CGRect)_openFrame; - (void)_openSetFrame:(CGRect)f; @end
@implementation NSWindow (OpenGeometry)
- (CGRect)frame { return [self _openFrame]; }
- (void)setFrame:(CGRect)f display:(BOOL)d { if (f.size.width > 1 && f.size.height > 1) [self _openSetFrame:f]; }
- (void)setFrame:(CGRect)f display:(BOOL)d animate:(BOOL)a { [self setFrame:f display:d]; }
- (void)setFrameOrigin:(CGPoint)p { CGRect f = [self _openFrame]; f.origin = p; [self _openSetFrame:f]; }
- (void)setContentSize:(CGSize)s { if (s.width <= 1 || s.height <= 1) return; CGRect f = [self _openFrame]; f.size = s; [self _openSetFrame:f]; }
- (CGRect)frameRectForContentRect:(CGRect)c { return c; }
- (CGRect)contentRectForFrameRect:(CGRect)f { return f; }
+ (CGRect)frameRectForContentRect:(CGRect)c styleMask:(NSUInteger)m { return c; }
+ (CGRect)contentRectForFrameRect:(CGRect)f styleMask:(NSUInteger)m { return f; }
- (void)center { }
- (CGRect)contentLayoutRect { return [[self contentView] bounds]; }
@end

@implementation NSScrollView (OpenGeometry)
+ (CGSize)frameSizeForContentSize:(CGSize)c horizontalScrollerClass:(Class)h verticalScrollerClass:(Class)v borderType:(NSUInteger)b controlSize:(NSInteger)cs scrollerStyle:(NSInteger)st { return c; }
+ (CGSize)contentSizeForFrameSize:(CGSize)f horizontalScrollerClass:(Class)h verticalScrollerClass:(Class)v borderType:(NSUInteger)b controlSize:(NSInteger)cs scrollerStyle:(NSInteger)st { return f; }
@end
@implementation NSScroller (OpenStyle)
+ (NSInteger)preferredScrollerStyle { return 1; }
@end

@implementation NSDocumentController (OpenActions)
- (void)newDocument:(id)sender { NSError *e = nil; [self openUntitledDocumentAndDisplay:YES error:&e]; }
- (void)openDocument:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel]; [p setAllowsMultipleSelection:YES]; [p setCanChooseFiles:YES];
    NSInteger rc = [p runModal]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: save panel -> %ld url %s\n", (long)rc, [[[p URL] description] UTF8String] ?: "nil");
    if (rc != 1) return;
    for (NSURL *u in [p URLs]) { NSError *e = nil; id d = [self openDocumentWithContentsOfURL:u display:YES error:&e]; if (!d) fprintf(stderr, "open: cannot open %s: %s\n", [[u path] UTF8String], [[e localizedDescription] UTF8String] ?: "?"); }
}
@end
@implementation NSWindow (OpenClose)
- (void)performClose:(id)sender { id d = [self delegate]; if ([d respondsToSelector:@selector(windowShouldClose:)] && !(BOOL)(NSInteger)[d performSelector:@selector(windowShouldClose:) withObject:self]) return; [self close]; }
- (void)close
{
    id d = [self delegate]; if ([d respondsToSelector:@selector(windowWillClose:)]) [d performSelector:@selector(windowWillClose:) withObject:[NSNotification notificationWithName:@"NSWindowWillCloseNotification" object:self]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NSWindowWillCloseNotification" object:self];
    [self orderOut:nil];
    id app = NSApp; BOOL any = NO; for (id w in [app respondsToSelector:@selector(windows)] ? [app performSelector:@selector(windows)] : @[]) if ([w isVisible] && w != self) any = YES;
    if (!any && [[app delegate] respondsToSelector:@selector(applicationShouldTerminateAfterLastWindowClosed:)] && (BOOL)(NSInteger)[[app delegate] performSelector:@selector(applicationShouldTerminateAfterLastWindowClosed:) withObject:app]) exit(0);
}
@end

/* ---- saving: the Save panel of the system, then the data of the program's document type ---- */
extern void OpenWindowDisplay(NSWindow *w);
@implementation NSDocument (OpenSave)
- (BOOL)writeToURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e
{
    NSData *d = nil; @try { d = [self dataOfType:t error:e]; } @catch (NSException *x) { fprintf(stderr, "open: dataOfType: exception %s\n", [[x reason] UTF8String]); }
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: dataOfType:%s -> %lu bytes, error %s\n", [t UTF8String], (unsigned long)[d length], e && *e ? [[*e description] UTF8String] : "nil");
    if (getenv("OPEN_DEBUG")) { unsigned int n = 0; Method *ms = class_copyMethodList([self class], &n); for (unsigned int i = 0; i < n; i++) { const char *nm = sel_getName(method_getName(ms[i])); if (strstr(nm, "rite") || strstr(nm, "ata") || strstr(nm, "rapper") || strstr(nm, "ave")) fprintf(stderr, "open: Document method %s\n", nm); } free(ms); }
    if (getenv("OPEN_DEBUG")) { id ts = nil; @try { ts = [self valueForKey:@"textStorage"]; } @catch (id x) { } fprintf(stderr, "open: doc textStorage %p (%s) len %lu; data %p\n", (__bridge void *)ts, ts ? class_getName([ts class]) : "-", ts ? (unsigned long)[[ts string] length] : 0, (__bridge void *)d); }
    if (!d && [self respondsToSelector:@selector(fileWrapperOfType:error:)]) {		/* programs with several formats (RTFD...) give a wrapper */
        NSFileWrapper *fw = nil; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: calling fileWrapperOfType %s\n", [t UTF8String]);
        @try { fw = ((id(*)(id, SEL, id, NSError **))objc_msgSend)(self, @selector(fileWrapperOfType:error:), t, e); } @catch (NSException *x) { fprintf(stderr, "open: fileWrapperOfType exception %s: %s\n", [[x name] UTF8String], [[x reason] UTF8String]); if (e) *e = [NSError errorWithDomain:@"OpenSave" code:1 userInfo:@{ NSLocalizedDescriptionKey: [x reason] ?: @"exception" }]; }
        if (getenv("OPEN_DEBUG")) { id ts = nil; @try { ts = [self valueForKey:@"textStorage"]; } @catch (id x) { }
            fprintf(stderr, "open: fileWrapperOfType %s -> %p err %s\n", [t UTF8String], (__bridge void *)fw, e && *e ? [[*e description] UTF8String] : "nil");
            if (ts) for (NSString *dt in @[@"NSRTF", @"NSPlainText"]) { NSError *e1 = nil; NSData *dd = ((id(*)(id, SEL, NSRange, id, NSError **))objc_msgSend)(ts, @selector(dataFromRange:documentAttributes:error:), NSMakeRange(0, [[ts string] length]), @{ @"DocumentType": dt }, &e1); fprintf(stderr, "open: probe %s -> %lu bytes err %s\n", [dt UTF8String], (unsigned long)[dd length], e1 ? [[e1 description] UTF8String] : "nil"); } }
        if (!fw && ([t isEqualToString:@"public.plain-text"] || [t isEqualToString:@"public.text"])) {		/* a plain text document the program's own writer refuses: its text as it is */
            id ts = nil; @try { ts = [self valueForKey:@"textStorage"]; } @catch (id x) { }
            if (ts) { if (e) *e = nil; return [[[ts string] dataUsingEncoding:NSUTF8StringEncoding] writeToURL:u options:NSDataWritingAtomic error:e]; }
        }
        if (fw) { NSError *e2 = nil; BOOL ok = [fw writeToURL:u options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&e2]; if (!ok && e) *e = e2; return ok; }
    }
    if (!d) return NO;
    return [d writeToURL:u options:NSDataWritingAtomic error:e];
}
- (NSData *)dataOfType:(NSString *)t error:(NSError **)e { return nil; }
- (void)_openFinishSave:(NSURL *)u type:(NSString *)t
{
    BOOL same = [[self fileURL] isEqual:u];
    [self setValue:u forKey:@"fileURL"]; if (t && !same) [self setValue:t forKey:@"fileType"];
    if (!same) [self setDisplayName:[[u lastPathComponent] copy]];
    for (NSWindowController *wc in [self windowControllers]) { NSWindow *w = [wc valueForKey:@"window"]; if (w) [w setTitle:[self displayName]]; }
}
- (void)performAsynchronousFileAccessUsingBlock:(void (^)(void (^)(void)))b { if (b) b(^{ }); }
- (void)performSynchronousFileAccessUsingBlock:(void (^)(void))b { if (b) b(); }
- (void)performActivityWithSynchronousWaiting:(BOOL)w usingBlock:(void (^)(void (^)(void)))b { if (b) b(^{ }); }
- (void)saveToURL:(NSURL *)u ofType:(NSString *)t forSaveOperation:(NSUInteger)op completionHandler:(void (^)(NSError *))h
{
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: base saveToURL %s op %lu\n", [[u description] UTF8String], (unsigned long)op);
    NSError *e = nil; BOOL ok = [self writeToURL:u ofType:t error:&e];
    if (ok && op != 2) { [self _openFinishSave:u type:t]; }		/* 2: save to (a copy) */
    if (ok && op != 2) { [self updateChangeCount:2]; for (NSWindowController *wc in [self windowControllers]) { NSWindow *w = [wc valueForKey:@"window"]; if (w) OpenWindowDisplay(w); } }
    if (h) h(ok ? nil : (e ?: [NSError errorWithDomain:NSCocoaErrorDomain code:512 userInfo:nil]));
}
- (void)_openSaveTo:(NSURL *)u type:(NSString *)t op:(NSUInteger)op
{
    void (^done)(NSError *) = ^(NSError *err) { if (err) fprintf(stderr, "open: save failed: %s\n", [[err localizedDescription] UTF8String] ?: "?"); };
    ((void(*)(id, SEL, id, id, NSUInteger, id))objc_msgSend)(self, @selector(saveToURL:ofType:forSaveOperation:completionHandler:), u, t, op, done);
}
- (void)saveDocumentAs:(id)sender
{
    NSSavePanel *p = [NSSavePanel savePanel]; [p setNameFieldStringValue:[self displayName] ?: @"Untitled"];
    if ([self fileURL]) [p setDirectoryURL:[[self fileURL] URLByDeletingLastPathComponent]];
    if ([p runModal] != 1) return;
    NSURL *u = [p URL]; NSError *e = nil; NSString *t = [self fileType] ?: @"";
    (void)e; [self _openSaveTo:u type:t op:([self fileURL] ? 3 : 0)];
}
- (void)saveDocument:(id)sender
{
    if (getenv("OPEN_DEBUG")) { id rt = nil; @try { rt = [self valueForKey:@"richText"]; } @catch (id x) { } fprintf(stderr, "open: richText %s\n", rt ? [[rt description] UTF8String] : "?"); }
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: saveDocument: %s url %s type %s\n", class_getName([self class]), [[[self fileURL] description] UTF8String] ?: "nil", [[self fileType] UTF8String] ?: "nil");
    if (![self fileURL]) { [self saveDocumentAs:sender]; return; }
    if (getenv("OPEN_DEBUG")) { id ts = nil; @try { ts = [self valueForKey:@"textStorage"]; } @catch (id x) { }
        if (ts) { NSError *e1 = nil; NSData *dd = ((id(*)(id, SEL, NSRange, id, NSError **))objc_msgSend)(ts, @selector(dataFromRange:documentAttributes:error:), NSMakeRange(0, [[ts string] length]), @{ @"DocumentType": @"NSRTF" }, &e1);
            fprintf(stderr, "open: probe dataFromRange rtf -> %lu bytes err %s\n", (unsigned long)[dd length], e1 ? [[e1 description] UTF8String] : "nil"); } }
    if (getenv("OPEN_DEBUG")) { id rt = nil; @try { rt = [self valueForKey:@"richText"]; } @catch (id x) { } fprintf(stderr, "open: fileType is %s richText %s\n", [[self fileType] UTF8String], rt ? [[rt description] UTF8String] : "?"); }
    [self _openSaveTo:[self fileURL] type:([[self fileType] isEqualToString:@"public.text"] ? @"public.plain-text" : ([self fileType] ?: @"")) op:0];
}
- (void)revertDocumentToSaved:(id)sender { }
- (void)printDocument:(id)sender { }
- (BOOL)validateMenuItem:(NSMenuItem *)it
{
    SEL a = [it action];
    if (a == @selector(printDocument:) || a == @selector(runPageLayout:)) return NO;
    if (a == @selector(revertDocumentToSaved:)) return [self fileURL] != nil;
    return YES;
}
- (void)runPageLayout:(id)sender { }
@end

/* ---- the rest of the document controller / application API programs call at launch ---- */
@implementation NSDocumentController (OpenMore)
- (void)setAutosavingDelay:(NSTimeInterval)t { }
- (NSTimeInterval)autosavingDelay { return 0; }
- (void)clearRecentDocuments:(id)s { }
- (NSArray *)recentDocumentURLs { return @[]; }
- (void)noteNewRecentDocument:(id)d { }
- (NSString *)defaultType { return [[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"] firstObject] objectForKey:@"CFBundleTypeName"]; }
- (NSArray *)documentClassNames { NSMutableArray *a = [NSMutableArray new]; for (NSDictionary *t in [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"]) if (t[@"NSDocumentClass"]) [a addObject:t[@"NSDocumentClass"]]; return a; }
- (BOOL)hasEditedDocuments { for (id d in [self documents]) if ([d isDocumentEdited]) return YES; return NO; }
- (void)closeAllDocumentsWithDelegate:(id)d didCloseAllSelector:(SEL)s contextInfo:(void *)c { }
- (void)reviewUnsavedDocumentsWithAlertTitle:(NSString *)t cancellable:(BOOL)c delegate:(id)d didReviewAllSelector:(SEL)s contextInfo:(void *)i { }
@end
static char kWinMenu;
@implementation NSApplication (OpenServices)
- (void)setServicesProvider:(id)p { }
- (void)registerServicesMenuSendTypes:(NSArray *)s returnTypes:(NSArray *)r { }
- (void)setServicesMenu:(id)m { }
- (void)setWindowsMenu:(id)m { objc_setAssociatedObject(self, &kWinMenu, m, OBJC_ASSOCIATION_RETAIN); }
- (id)windowsMenu { return objc_getAssociatedObject(self, &kWinMenu); }
- (void)addWindowsItem:(id)w title:(NSString *)t filename:(BOOL)f { }
- (void)changeWindowsItem:(id)w title:(NSString *)t filename:(BOOL)f { }
- (void)removeWindowsItem:(id)w { }
- (void)updateWindowsItem:(id)w { }
- (void)setHelpMenu:(id)m { }
@end

/* ---- window attributes programs set and read (kept here; the level goes to wsd with the window) ---- */
static char kWA;
static NSMutableDictionary *WA(NSWindow *w) { NSMutableDictionary *d = objc_getAssociatedObject(w, &kWA); if (!d) { d = [NSMutableDictionary new]; objc_setAssociatedObject(w, &kWA, d, OBJC_ASSOCIATION_RETAIN); } return d; }
@implementation NSWindow (OpenAttributes)
- (CGFloat)alphaValue { NSNumber *n = WA(self)[@"alpha"]; return n ? [n doubleValue] : 1.0; }
- (void)setAlphaValue:(CGFloat)a { WA(self)[@"alpha"] = @(a); }
- (NSInteger)level { return [WA(self)[@"level"] integerValue]; }
- (void)setLevel:(NSInteger)l { WA(self)[@"level"] = @(l); }
- (BOOL)isOpaque { NSNumber *n = WA(self)[@"opaque"]; return n ? [n boolValue] : YES; }
- (void)setOpaque:(BOOL)o { WA(self)[@"opaque"] = @(o); }
- (BOOL)hasShadow { NSNumber *n = WA(self)[@"shadow"]; return n ? [n boolValue] : YES; }
- (void)setHasShadow:(BOOL)b { WA(self)[@"shadow"] = @(b); }
- (id)backgroundColor { return WA(self)[@"bg"]; }
- (void)setBackgroundColor:(id)c { if (c) WA(self)[@"bg"] = c; }
- (NSUInteger)collectionBehavior { return [WA(self)[@"cb"] unsignedIntegerValue]; }
- (void)setCollectionBehavior:(NSUInteger)b { WA(self)[@"cb"] = @(b); }
- (BOOL)isMovableByWindowBackground { return [WA(self)[@"mbwb"] boolValue]; }
- (void)setMovableByWindowBackground:(BOOL)b { WA(self)[@"mbwb"] = @(b); }
- (BOOL)isMovable { NSNumber *n = WA(self)[@"movable"]; return n ? [n boolValue] : YES; }
- (void)setMovable:(BOOL)b { WA(self)[@"movable"] = @(b); }
- (BOOL)hidesOnDeactivate { return [WA(self)[@"hod"] boolValue]; }
- (void)setHidesOnDeactivate:(BOOL)b { WA(self)[@"hod"] = @(b); }
- (BOOL)isReleasedWhenClosed { NSNumber *n = WA(self)[@"rwc"]; return n ? [n boolValue] : YES; }
- (void)setReleasedWhenClosed:(BOOL)b { WA(self)[@"rwc"] = @(b); }
- (CGSize)minSize { NSValue *v = WA(self)[@"min"]; CGSize s = CGSizeZero; if (v) [v getValue:&s]; return s; }
- (void)setMinSize:(CGSize)s { WA(self)[@"min"] = [NSValue valueWithBytes:&s objCType:@encode(CGSize)]; }
- (CGSize)maxSize { NSValue *v = WA(self)[@"max"]; CGSize s = CGSizeMake(1e7, 1e7); if (v) [v getValue:&s]; return s; }
- (void)setMaxSize:(CGSize)s { WA(self)[@"max"] = [NSValue valueWithBytes:&s objCType:@encode(CGSize)]; }
@end

/* the nib of a document has its window on the document ("window" outlet of the File's Owner): kept here and handed to the window controller when it has none */
static char kDocWin;
@implementation NSDocument (OpenWindowOutlet)
- (void)setWindow:(NSWindow *)w { objc_setAssociatedObject(self, &kDocWin, w, OBJC_ASSOCIATION_ASSIGN); for (NSWindowController *wc in [self windowControllers]) if (![wc valueForKey:@"window"]) [wc setValue:w forKey:@"window"]; }
- (NSWindow *)window { NSWindow *w = objc_getAssociatedObject(self, &kDocWin); if (w) return w; return [[[self windowControllers] firstObject] valueForKey:@"window"]; }
@end

/* ---- a minimal layer (apps set layer.backgroundColor/cornerRadius on a view): kept as properties, the background is painted under the view ---- */
@interface OpenLayer : NSObject { @public CGColorRef bg; CGFloat radius, opacity; }
@end
@implementation OpenLayer
- (instancetype)init { self = [super init]; opacity = 1; return self; }
- (CGColorRef)backgroundColor { return bg; }
- (void)setBackgroundColor:(CGColorRef)c { if (c) CFRetain(c); if (bg) CFRelease(bg); bg = c; }
- (CGFloat)cornerRadius { return radius; }
- (void)setCornerRadius:(CGFloat)r { radius = r; }
- (float)opacity { return opacity; }
- (void)setOpacity:(float)o { opacity = o; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s { NSMethodSignature *m = [super methodSignatureForSelector:s]; if (m) return m; return [NSMethodSignature signatureWithObjCTypes:(strncmp(sel_getName(s), "set", 3) == 0 ? "v@:@" : "@@:")]; }
- (void)forwardInvocation:(NSInvocation *)i { }		/* the other properties (borders, shadows, masks) are not painted */
@end
static char kLayer;
@implementation NSView (OpenLayer)
- (id)layer { return objc_getAssociatedObject(self, &kLayer); }
- (void)setLayer:(id)l { objc_setAssociatedObject(self, &kLayer, l, OBJC_ASSOCIATION_RETAIN); }
- (BOOL)wantsLayer { return [self layer] != nil; }
- (void)setWantsLayer:(BOOL)b { if (b && ![self layer]) [self setLayer:[OpenLayer new]]; }
- (void)setToolTip:(NSString *)t { }
@end
@implementation NSWindowController (OpenMisc)
- (void)setShouldCascadeWindows:(BOOL)b { }
@end
@implementation NSWindow (OpenMisc)
- (void)orderFront:(id)s { [self makeKeyAndOrderFront:s]; }
- (id)windowController { return objc_getAssociatedObject(self, "OpenWC"); }
- (void)setWindowController:(id)c { objc_setAssociatedObject(self, "OpenWC", c, OBJC_ASSOCIATION_ASSIGN); }
@end
void OpenLayerPaint(NSView *v, CGContextRef cg, CGRect b)
{
    OpenLayer *l = [v layer]; if (![l isKindOfClass:[OpenLayer class]] || !l->bg) return;
    CGContextSaveGState(cg); CGContextSetFillColorWithColor(cg, l->bg);
    if (l->radius > 0) { CGPathRef p = CGPathCreateWithRoundedRect(b, l->radius, l->radius, NULL); CGContextAddPath(cg, p); CGContextFillPath(cg); CGPathRelease(p); } else CGContextFillRect(cg, b);
    CGContextRestoreGState(cg);
}

/* UIFoundation looks this constant up when it saves an attributed string */
NSString *const NSAppearanceNameSystem = @"NSAppearanceNameSystem";

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
    [self windowDidLoad];
}
- (void)windowWillLoad { }
- (void)windowDidLoad { }
- (BOOL)isWindowLoaded { return [objc_getAssociatedObject(self, &kLoaded) boolValue] || [self windowNibName] == nil; }
- (void)showWindow:(id)sender { [self loadWindow]; NSWindow *w = [self valueForKey:@"window"]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: showWindow: %s window %p\n", class_getName([self class]), (__bridge void *)w); if (w && ![[w title] length]) { id doc = [self valueForKey:@"document"]; NSString *t = doc ? [doc displayName] : nil; if ([t length]) [w setTitle:t]; }
    [w makeKeyAndOrderFront:sender]; }
@end

@implementation NSDocument (OpenCreate)
- (instancetype)initWithType:(NSString *)t error:(NSError **)e { self = [self init]; if (self) [self setValue:t forKey:@"fileType"]; return self; }
- (instancetype)initWithContentsOfURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e
{
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
    NSDocument *doc = [[k alloc] initWithType:t[@"CFBundleTypeName"] ?: @"" error:e]; if (!doc) return nil;
    [self addDocument:doc]; [doc makeWindowControllers]; if (display) [doc showWindows];
    return doc;
}
- (id)openDocumentWithContentsOfURL:(NSURL *)u display:(BOOL)display error:(NSError **)e
{
    NSDictionary *t = [self _openTypeForExtension:[u pathExtension]]; Class k = [self _openClassFor:t]; if (!k) return nil;
    NSDocument *doc = [[k alloc] initWithContentsOfURL:u ofType:t[@"CFBundleTypeName"] ?: @"" error:e]; if (!doc) return nil;
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
    if ([p runModal] != 1) return;
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
@implementation NSDocument (OpenSave)
- (BOOL)writeToURL:(NSURL *)u ofType:(NSString *)t error:(NSError **)e
{
    NSData *d = [self dataOfType:t error:e]; if (!d) return NO;
    return [d writeToURL:u options:NSDataWritingAtomic error:e];
}
- (NSData *)dataOfType:(NSString *)t error:(NSError **)e { return nil; }
- (void)_openFinishSave:(NSURL *)u type:(NSString *)t
{
    [self setValue:u forKey:@"fileURL"]; if (t) [self setValue:t forKey:@"fileType"];
    [self setDisplayName:[[u lastPathComponent] copy]];
    for (NSWindowController *wc in [self windowControllers]) { NSWindow *w = [wc valueForKey:@"window"]; if (w) [w setTitle:[self displayName]]; }
}
- (void)saveDocumentAs:(id)sender
{
    NSSavePanel *p = [NSSavePanel savePanel]; [p setNameFieldStringValue:[self displayName] ?: @"Untitled"];
    if ([self fileURL]) [p setDirectoryURL:[[self fileURL] URLByDeletingLastPathComponent]];
    if ([p runModal] != 1) return;
    NSURL *u = [p URL]; NSError *e = nil; NSString *t = [self fileType] ?: @"";
    if ([self writeToURL:u ofType:t error:&e]) [self _openFinishSave:u type:nil]; else fprintf(stderr, "open: save failed: %s\n", [[e localizedDescription] UTF8String] ?: "?");
}
- (void)saveDocument:(id)sender
{
    if (![self fileURL]) { [self saveDocumentAs:sender]; return; }
    NSError *e = nil; if (![self writeToURL:[self fileURL] ofType:[self fileType] ?: @"" error:&e]) fprintf(stderr, "open: save failed: %s\n", [[e localizedDescription] UTF8String] ?: "?");
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

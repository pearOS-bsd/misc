/* OpenDocument.m — NSWindowController (nib-driven windows), NSDocument creation/showing and NSDocumentController: untitled and opened documents, as far as a document-based app needs at launch */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSDocument.h"
#import "NSDocumentController.h"
#import "NSWindowController.h"

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
    [[NSBundle mainBundle] loadNibNamed:n owner:[self owner] topLevelObjects:nil];
    [self windowDidLoad];
}
- (void)windowWillLoad { }
- (void)windowDidLoad { }
- (BOOL)isWindowLoaded { return [objc_getAssociatedObject(self, &kLoaded) boolValue] || [self windowNibName] == nil; }
- (void)showWindow:(id)sender { [self loadWindow]; NSWindow *w = [self valueForKey:@"window"]; if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: showWindow: %s window %p\n", class_getName([self class]), (__bridge void *)w); [w makeKeyAndOrderFront:sender]; }
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

/* OpenNib.m — loading of compiled nibs (NIBArchive, the output of ibtool): -[NSBundle loadNibNamed:owner:topLevelObjects:].
 * An interpreter of the archive of its own (not NSKeyedUnarchiver): it builds our menus, windows and views from the objects and applies the connections.
 * Unknown classes are logged: `open: nib: unknown class X`. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSApplication.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSMenu.h"
#import "NSMenuItem.h"
#import "NSButton.h"
#import "NSTextField.h"
#import "NSScrollView.h"

@interface OpenRef : NSObject { @public NSUInteger i; } @end
@implementation OpenRef @end

@interface OpenNib : NSObject {
    NSData *d; NSMutableArray *objs;			/* each: @{@"c": class name, @"p": array of [key, value]} */
    NSMutableDictionary *cache; NSMutableArray *topLevel; id owner; NSUInteger pos;
}
- (instancetype)initWithData:(NSData *)data owner:(id)o;
- (BOOL)instantiate:(NSArray **)top;
@end

@implementation OpenNib
- (uint64_t)vint { const uint8_t *b = [d bytes]; uint64_t r = 0; int s = 0; for (;;) { uint8_t c = b[pos++]; r |= (uint64_t)(c & 0x7f) << s; s += 7; if (c & 0x80) return r; } }
- (instancetype)initWithData:(NSData *)data owner:(id)o
{
    self = [super init]; d = data; owner = o; cache = [NSMutableDictionary new]; topLevel = [NSMutableArray new];
    const uint8_t *b = [d bytes]; if ([d length] < 50 || memcmp(b, "NIBArchive", 10)) return nil;
    uint32_t h[10]; memcpy(h, b + 10, 40);
    uint32_t nobj = h[2], oobj = h[3], nkey = h[4], okey = h[5], nval = h[6], oval = h[7], ncls = h[8], ocls = h[9];
    NSMutableArray *keys = [NSMutableArray new], *cls = [NSMutableArray new], *vals = [NSMutableArray new]; NSMutableArray *oe = [NSMutableArray new];
    pos = okey; for (uint32_t i = 0; i < nkey; i++) { uint64_t n = [self vint]; [keys addObject:[[NSString alloc] initWithBytes:b + pos length:n encoding:NSUTF8StringEncoding] ?: @""]; pos += n; }
    pos = ocls; for (uint32_t i = 0; i < ncls; i++) { uint64_t n = [self vint], e = [self vint]; pos += 4 * e; NSString *s = [[NSString alloc] initWithBytes:b + pos length:(n && b[pos + n - 1] == 0 ? n - 1 : n) encoding:NSUTF8StringEncoding]; [cls addObject:s ?: @""]; pos += n; }
    pos = oval;
    for (uint32_t i = 0; i < nval; i++) {
        uint64_t k = [self vint]; uint8_t t = b[pos++]; id x = [NSNull null];
        switch (t) {
        case 0: x = @((int8_t)b[pos]); pos += 1; break;
        case 1: { int16_t v; memcpy(&v, b + pos, 2); x = @(v); pos += 2; break; }
        case 2: { int32_t v; memcpy(&v, b + pos, 4); x = @(v); pos += 4; break; }
        case 3: { int64_t v; memcpy(&v, b + pos, 8); x = @(v); pos += 8; break; }
        case 4: x = @YES; break; case 5: x = @NO; break;
        case 6: { float v; memcpy(&v, b + pos, 4); x = @(v); pos += 4; break; }
        case 7: { double v; memcpy(&v, b + pos, 8); x = @(v); pos += 8; break; }
        case 8: { uint64_t n = [self vint]; x = [NSData dataWithBytes:b + pos length:n]; pos += n; break; }
        case 9: break;
        case 10: { uint32_t v; memcpy(&v, b + pos, 4); OpenRef *r = [OpenRef new]; r->i = v; x = r; pos += 4; break; }
        default: return nil;
        }
        [vals addObject:@[keys[k], x]];
    }
    objs = [NSMutableArray new]; pos = oobj;
    for (uint32_t i = 0; i < nobj; i++) {
        uint64_t c = [self vint], vi = [self vint], vc = [self vint];
        [objs addObject:@{ @"c": cls[c], @"p": [vals subarrayWithRange:NSMakeRange(vi, vc)] }];
    }
    (void)oe; return self;
}
- (id)raw:(NSString *)key of:(NSUInteger)i { for (NSArray *kv in objs[i][@"p"]) if ([kv[0] isEqualToString:key]) return kv[1]; return nil; }
- (NSArray *)rawAll:(NSString *)key of:(NSUInteger)i { NSMutableArray *a = [NSMutableArray new]; for (NSArray *kv in objs[i][@"p"]) if ([kv[0] isEqualToString:key]) [a addObject:kv[1]]; return a; }
- (id)val:(id)x { return [x isKindOfClass:[OpenRef class]] ? [self decode:((OpenRef *)x)->i] : ([x isKindOfClass:[NSNull class]] ? nil : x); }
- (id)get:(NSString *)key of:(NSUInteger)i { return [self val:[self raw:key of:i]]; }
- (NSArray *)items:(NSUInteger)i { NSMutableArray *a = [NSMutableArray new]; for (NSArray *kv in objs[i][@"p"]) if ([kv[0] isEqualToString:@"UINibEncoderEmptyKey"] || [kv[0] isEqualToString:@"NS.objects"]) { id o = [self val:kv[1]]; if (o) [a addObject:o]; } return a; }
static CGRect ParseRect(NSString *s) { double a = 0, b = 0, c = 0, e = 0; sscanf([s UTF8String] ?: "", "{{%lf, %lf}, {%lf, %lf}}", &a, &b, &c, &e); return CGRectMake(a, b, c, e); }
static CGSize ParseSize(NSString *s) { double a = 0, b = 0; sscanf([s UTF8String] ?: "", "{%lf, %lf}", &a, &b); return CGSizeMake(a, b); }
- (NSString *)str:(id)o { return [o isKindOfClass:[NSString class]] ? o : nil; }

- (id)decode:(NSUInteger)i
{
    NSNumber *key = @(i); id c = cache[key]; if (c) return [c isKindOfClass:[NSNull class]] ? nil : c;
    NSString *cn = objs[i][@"c"]; id r = nil;
    cache[key] = [NSNull null];			/* cycles: back references see nil */
    if ([cn isEqualToString:@"NSString"] || [cn isEqualToString:@"NSMutableString"] || [cn isEqualToString:@"NSLocalizableString"]) {
        NSData *bytes = [self raw:@"NS.bytes" of:i]; r = [bytes isKindOfClass:[NSData class]] ? [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] : @"";
    } else if ([cn isEqualToString:@"NSArray"] || [cn isEqualToString:@"NSMutableArray"]) { r = [[self items:i] mutableCopy];
    } else if ([cn isEqualToString:@"NSSet"] || [cn isEqualToString:@"NSMutableSet"]) { r = [NSMutableSet setWithArray:[self items:i]];
    } else if ([cn isEqualToString:@"NSDictionary"] || [cn isEqualToString:@"NSMutableDictionary"]) {
        NSArray *k = [self get:@"NS.keys" of:i] ?: @[], *v = [self get:@"NS.objects" of:i] ?: @[]; NSMutableDictionary *m = [NSMutableDictionary new];
        for (NSUInteger j = 0; j < MIN([k count], [v count]); j++) m[k[j]] = v[j]; r = m;
    } else if ([cn isEqualToString:@"NSValue"]) { id s = [self get:@"NS.sizeval" of:i] ?: [self get:@"NS.rectval" of:i] ?: [self get:@"NS.pointval" of:i]; r = s ?: @"";
    } else if ([cn isEqualToString:@"NSCustomObject"]) {
        NSString *name = [self get:@"NSClassName" of:i];
        if ([name isEqualToString:@"NSApplication"] && owner) r = owner;
        else if ([name isEqualToString:@"NSApplication"]) r = [NSApplication sharedApplication];
        else {
            Class k = NSClassFromString(name);
            if (!k) { NSString *mod = nil; id ref = [self get:@"IBClassReference" of:i]; (void)ref; mod = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"]; k = NSClassFromString([NSString stringWithFormat:@"%@.%@", mod, name]); }
            r = k ? [[k alloc] init] : nil; if (!k) fprintf(stderr, "open: nib: custom object class %s not found\n", [name UTF8String]);
        }
    } else if ([cn isEqualToString:@"NSMenu"]) {
        NSMenu *m = [[NSMenu alloc] initWithTitle:[self get:@"NSTitle" of:i] ?: @""]; cache[key] = m; r = m;
        for (NSMenuItem *it in [self get:@"NSMenuItems" of:i] ?: @[]) if ([it isKindOfClass:[NSMenuItem class]]) [m addItem:it];
        NSString *nm = [self get:@"NSName" of:i];		/* the menus the application knows by name */
        if ([nm isEqualToString:@"_NSMainMenu"]) [NSApp setMainMenu:m];
        else if ([nm isEqualToString:@"_NSWindowsMenu"] && [NSApp respondsToSelector:@selector(setWindowsMenu:)]) [NSApp performSelector:@selector(setWindowsMenu:) withObject:m];
        else if ([nm isEqualToString:@"_NSServicesMenu"] && [NSApp respondsToSelector:@selector(setServicesMenu:)]) [NSApp performSelector:@selector(setServicesMenu:) withObject:m];
        else if ([nm isEqualToString:@"_NSHelpMenu"] && [NSApp respondsToSelector:@selector(setHelpMenu:)]) [NSApp performSelector:@selector(setHelpMenu:) withObject:m];
    } else if ([cn isEqualToString:@"NSMenuItem"]) {
        NSMenuItem *it;
        if ([[self raw:@"NSIsSeparator" of:i] boolValue]) it = [NSMenuItem separatorItem];
        else it = [[NSMenuItem alloc] initWithTitle:[self get:@"NSTitle" of:i] ?: @"" action:NULL keyEquivalent:[self get:@"NSKeyEquiv" of:i] ?: @""];
        cache[key] = it; r = it;
        id sub = [self get:@"NSSubmenu" of:i]; if ([sub isKindOfClass:[NSMenu class]]) [it setSubmenu:sub];
    } else if ([cn isEqualToString:@"NSWindowTemplate"]) {
        CGRect f = ParseRect([self get:@"NSWindowRect" of:i]); NSUInteger mask = [[self raw:@"NSWindowStyleMask" of:i] unsignedIntegerValue];
        Class k = NSClassFromString([self get:@"NSWindowClass" of:i] ?: @"NSWindow") ?: [NSWindow class];
        NSWindow *w = [[k alloc] initWithContentRect:f styleMask:mask backing:NSBackingStoreBuffered defer:NO]; cache[key] = w; r = w;
        id title = [self get:@"NSWindowTitle" of:i]; if (title) [w setTitle:title];
        id cv = [self get:@"NSWindowView" of:i]; if ([cv isKindOfClass:[NSView class]]) { [cv setFrame:CGRectMake(0, 0, f.size.width, f.size.height)]; [w setContentView:cv]; }
    } else if ([cn isEqualToString:@"NSView"] || [cn isEqualToString:@"NSCustomView"] || [cn isEqualToString:@"NSBox"] || [cn isEqualToString:@"NSScrollView"] || [cn isEqualToString:@"NSClipView"] || [cn isEqualToString:@"NSTextView"]
               || [cn isEqualToString:@"NSTextField"] || [cn isEqualToString:@"NSButton"] || [cn isEqualToString:@"NSPopUpButton"] || [cn isEqualToString:@"NSSlider"] || [cn isEqualToString:@"NSProgressIndicator"] || [cn isEqualToString:@"NSTableView"]
               || [cn isEqualToString:@"NSClassSwapper"] || [cn isEqualToString:@"NSScroller"] || [cn isEqualToString:@"NSSplitView"] || [cn isEqualToString:@"NSTabView"] || [cn isEqualToString:@"NSImageView"] || [cn isEqualToString:@"NSSecureTextField"] || [cn isEqualToString:@"NSSearchField"] || [cn isEqualToString:@"NSStackView"]) {
        NSString *cc = ([cn isEqualToString:@"NSCustomView"] || [cn isEqualToString:@"NSClassSwapper"]) ? [self get:@"NSClassName" of:i] : cn; Class k = NSClassFromString(cc) ?: NSClassFromString(cn);
        if (![k isSubclassOfClass:[NSView class]]) { r = k ? [[k alloc] init] : nil; cache[key] = r ?: [NSNull null]; return r; }			/* a class swapper can stand for a cell or another object that is no view */
        id frameStr = [self get:@"NSFrame" of:i]; CGRect f = frameStr ? ParseRect(frameStr) : CGRectMake(0, 0, ParseSize([self get:@"NSFrameSize" of:i]).width, ParseSize([self get:@"NSFrameSize" of:i]).height);
        NSView *v = [[k alloc] initWithFrame:f]; cache[key] = v; r = v;
        for (id sv in [self get:@"NSSubviews" of:i] ?: @[]) {
            if (![sv isKindOfClass:[NSView class]]) continue;
            if ([v isKindOfClass:[NSScrollView class]] && [sv isKindOfClass:NSClassFromString(@"NSClipView")]) { NSView *dv = [[sv subviews] firstObject]; if (dv) { [dv removeFromSuperview]; [(NSScrollView *)v setDocumentView:dv]; } continue; }		/* the scroll view has its own clip view */
            [v addSubview:sv];
        }
        id cell = [self get:@"NSCell" of:i]; id contents = [cell isKindOfClass:[NSDictionary class]] ? cell[@"title"] : nil; (void)contents;
        if ([v isKindOfClass:[NSButton class]] || [v isKindOfClass:[NSTextField class]]) {
            NSUInteger ci = [(OpenRef *)[self raw:@"NSCell" of:i] isKindOfClass:[OpenRef class]] ? ((OpenRef *)[self raw:@"NSCell" of:i])->i : NSNotFound;
            if (ci != NSNotFound) { id t = [self get:@"NSContents" of:ci]; if ([t isKindOfClass:[NSString class]]) { if ([v isKindOfClass:[NSButton class]]) [(NSButton *)v setTitle:t]; else [(NSTextField *)v setStringValue:t]; } }
        }
        { id doc = [self get:@"NSDocView" of:i]; if ([doc isKindOfClass:[NSView class]]) [v addSubview:doc]; }			/* the clip view holds the document view */
    } else if ([cn isEqualToString:@"NSNibOutletConnector"] || [cn isEqualToString:@"NSNibControlConnector"] || [cn isEqualToString:@"IBClassReference"]) {
        r = nil;			/* applied after everything is built */
    } else { fprintf(stderr, "open: nib: unknown class %s\n", [cn UTF8String]); }
    cache[key] = r ?: [NSNull null]; return r;
}

- (BOOL)instantiate:(NSArray **)top
{
    NSUInteger root = 1;				/* the NSIBObjectData object */
    if (![objs[root][@"c"] isEqualToString:@"NSIBObjectData"]) { for (NSUInteger j = 0; j < [objs count]; j++) if ([objs[j][@"c"] isEqualToString:@"NSIBObjectData"]) root = j; }
    { id rr = [self raw:@"NSRoot" of:root]; if ([rr isKindOfClass:[OpenRef class]] && owner) cache[@(((OpenRef *)rr)->i)] = owner; }		/* File's Owner is the object the caller passed */
    for (id o in [self get:@"NSObjectsKeys" of:root] ?: @[]) (void)o;		/* decoding walks the graph through the connections and the windows */
    NSArray *conns = [self get:@"NSConnections" of:root] ?: @[];
    NSUInteger n = [objs count];
    for (NSUInteger j = 0; j < n; j++) { NSString *c = objs[j][@"c"]; if ([c isEqualToString:@"NSWindowTemplate"] || [c isEqualToString:@"NSMenu"]) [self decode:j]; }
    for (NSUInteger j = 0; j < n; j++) {
        NSString *c = objs[j][@"c"]; BOOL outlet = [c isEqualToString:@"NSNibOutletConnector"], control = [c isEqualToString:@"NSNibControlConnector"]; if (!outlet && !control) continue;
        id src = [self get:@"NSSource" of:j], dst = [self get:@"NSDestination" of:j]; NSString *label = [self get:@"NSLabel" of:j]; if (!src || !label) continue;
        @try {
            if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: nib: %s %s.%s = %s\n", outlet ? "outlet" : "action", src ? class_getName([src class]) : "nil", [label UTF8String], dst ? class_getName([dst class]) : "nil");
            if (outlet) [src setValue:dst forKey:label];
            else { SEL a = NSSelectorFromString(label); if ([src respondsToSelector:@selector(setTarget:)]) [src performSelector:@selector(setTarget:) withObject:dst]; if ([src respondsToSelector:@selector(setAction:)]) ((void(*)(id, SEL, SEL))objc_msgSend)(src, @selector(setAction:), a); }
        } @catch (NSException *e) { fprintf(stderr, "open: nib: connection %s failed: %s\n", [label UTF8String], [[e reason] UTF8String]); }
    }
    (void)conns;
    for (id vw in [self get:@"NSVisibleWindows" of:root] ?: @[]) if ([vw isKindOfClass:[NSWindow class]]) [vw makeKeyAndOrderFront:nil];
    NSMutableArray *t = [NSMutableArray new]; for (id v in [cache allValues]) if ([v isKindOfClass:[NSWindow class]] || [v isKindOfClass:[NSMenu class]]) [t addObject:v];
    if (top) *top = t;
    for (id v in [cache allValues]) if ([v isKindOfClass:[NSMenu class]] && [NSApp mainMenu] == nil) { /* the first menu without a super menu is the main menu */ }
    return YES;
}
@end

@implementation NSBundle (OpenNib)
- (BOOL)loadNibNamed:(NSString *)name owner:(id)owner topLevelObjects:(NSArray **)top
{
    NSString *p = [self pathForResource:name ofType:@"nib"];
    if (!p) { fprintf(stderr, "open: nib %s not found\n", [name UTF8String]); return NO; }
    NSData *data = [NSData dataWithContentsOfFile:p]; if (!data) { data = [NSData dataWithContentsOfFile:[p stringByAppendingPathComponent:@"keyedobjects.nib"]]; }
    OpenNib *n = [[OpenNib alloc] initWithData:data owner:owner];
    if (!n) { fprintf(stderr, "open: nib %s: not a NIBArchive\n", [p UTF8String]); return NO; }
    NSArray *t = nil; BOOL ok = [n instantiate:&t]; if (top) *top = t;
    if (owner) objc_setAssociatedObject(owner, (__bridge const void *)name, n, OBJC_ASSOCIATION_RETAIN);			/* the objects of the nib live as long as its owner (outlets are often weak) */
    else { static NSMutableArray *keep; if (!keep) keep = [NSMutableArray new]; [keep addObject:n]; }
    fprintf(stderr, "open: nib %s loaded (%lu top-level objects)\n", [name UTF8String], (unsigned long)[t count]);
    return ok;
}
@end

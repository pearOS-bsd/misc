/*
 * NSAppearance.m — 1:1 (core). See NSAppearance.h for the interface evidence.
 *
 * Identified by _name. +appearanceNamed: returns a cached singleton for each
 * standard name. allowsVibrancy is YES for the vibrant appearances (the
 * _allowsVibrancy flag bit). bestMatchFromAppearancesWithNames: returns an exact
 * name match if present, else the first candidate in the same light/dark family
 * as the receiver, else the first candidate. The current drawing appearance is a
 * thread-local the drawing code consults; performAsCurrentDrawingAppearance:
 * installs it for the duration of the block. CoreUI rendering is stage2.
 */
#import "NSAppearance.h"

NSAppearanceName const NSAppearanceNameAqua = @"NSAppearanceNameAqua";
NSAppearanceName const NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
NSAppearanceName const NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
NSAppearanceName const NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
NSAppearanceName const NSAppearanceNameAccessibilityHighContrastAqua = @"NSAppearanceNameAccessibilityHighContrastAqua";
NSAppearanceName const NSAppearanceNameAccessibilityHighContrastDarkAqua = @"NSAppearanceNameAccessibilityHighContrastDarkAqua";

static NSAppearance *sCurrentDrawingAppearance = nil;

@implementation NSAppearance {
    NSAppearanceName _name;
    BOOL _allowsVibrancy;
}

- (instancetype)initWithAppearanceNamed:(NSAppearanceName)name bundle:(NSBundle *)bundle
{
    if (name.length == 0) return nil;
    self = [super init];
    if (self) {
        _name = [name copy];
        _allowsVibrancy = [name isEqualToString:NSAppearanceNameVibrantLight] ||
                          [name isEqualToString:NSAppearanceNameVibrantDark];
    }
    return self;
}

+ (NSAppearance *)appearanceNamed:(NSAppearanceName)name
{
    static NSMutableDictionary<NSString *, NSAppearance *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
    @synchronized (cache) {
        NSAppearance *a = cache[name];
        if (!a) {
            a = [[NSAppearance alloc] initWithAppearanceNamed:name bundle:nil];
            if (a) cache[name] = a;
        }
        return a;
    }
}

+ (NSAppearance *)currentDrawingAppearance { return sCurrentDrawingAppearance; }
+ (void)setCurrentDrawingAppearance:(NSAppearance *)a { sCurrentDrawingAppearance = a; }
+ (NSAppearance *)currentAppearance { return sCurrentDrawingAppearance; }

- (NSAppearanceName)name { return _name; }
- (BOOL)allowsVibrancy { return _allowsVibrancy; }

static BOOL NSAppearanceIsDark(NSString *name)
{
    return [name rangeOfString:@"Dark"].location != NSNotFound;
}

- (NSAppearanceName)bestMatchFromAppearancesWithNames:(NSArray<NSAppearanceName> *)appearances
{
    if (appearances.count == 0) return nil;
    /* 1: exact match */
    for (NSAppearanceName n in appearances)
        if ([n isEqualToString:_name]) return n;
    /* 2: same light/dark family */
    BOOL selfDark = NSAppearanceIsDark(_name);
    for (NSAppearanceName n in appearances)
        if (NSAppearanceIsDark(n) == selfDark) return n;
    /* 3: first candidate */
    return appearances.firstObject;
}

- (void)performAsCurrentDrawingAppearance:(void (NS_NOESCAPE ^)(void))block
{
    NSAppearance *prev = sCurrentDrawingAppearance;
    sCurrentDrawingAppearance = self;
    @try { if (block) block(); }
    @finally { sCurrentDrawingAppearance = prev; }
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSAppearance class]]) return NO;
    return [((NSAppearance *)object)->_name isEqualToString:_name];
}
- (NSUInteger)hash { return _name.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"%@ name=%@", [super description], _name]; }

@end

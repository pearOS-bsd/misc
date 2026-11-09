/*
 * NSScreen.m — 1:1 (core). See NSScreen.h for the interface evidence.
 *
 * Real behaviour (from the AppKit disassembly / documented contract):
 *   - +screens returns the window server's display list, cached per
 *     display-change seed (+_displayChangeSeed). Empty only before the server
 *     connection is up. Enumerating the real list is stage2.
 *   - +mainScreen is the screen with the key window, else the one with the menu
 *     bar; AppKit falls back to screens[0]. The key-window refinement is stage2;
 *     here +mainScreen == screens.firstObject.
 *   - +deepestScreen is the screen with the greatest -depth.
 *   - NSScreen equality/hash is by display (screen number), not by pointer —
 *     two NSScreen objects for the same display are equal.
 *   - -convertRectToBacking: / -FromBacking: / -backingAlignedRect:options:
 *     scale by -backingScaleFactor. Transcribed as the exact arithmetic.
 *
 * The opaque `_state` ivar (CGS display-state handle) is modelled here by the
 * concrete display fields; the colorSpace / safeAreaInsets / displayLink and
 * the live server enumeration are stage2.
 */
#import "NSScreen.h"

static NSArray<NSScreen *> *sScreens = nil;
static CGFloat sFallbackBackingScaleFactor = 2.0; /* Retina default; set by glue */

@implementation NSScreen {
    NSInteger _screenNumberIvar;   /* part of _state */
    CGRect    _frame;
    CGRect    _visibleFrame;
    CGFloat   _backingScaleFactor;
    NSInteger _depth;
}

- (instancetype)_initWithScreenNumber:(NSInteger)screenNumber
                                frame:(CGRect)frame
                         visibleFrame:(CGRect)visibleFrame
                   backingScaleFactor:(CGFloat)scale
                                depth:(NSInteger)depth
{
    self = [super init];
    if (self) {
        _screenNumberIvar = screenNumber;
        _frame = frame;
        _visibleFrame = visibleFrame;
        _backingScaleFactor = scale;
        _depth = depth;
    }
    return self;
}

/* Synthesise the fallback screen used when the window-server list is empty:
 * a single 1440x900 @scale display, menu bar (25pt) reserved at the top of the
 * visible frame. This keeps -frame/-backingScaleFactor meaningful off-server. */
+ (NSScreen *)_fallbackScreen
{
    CGRect frame = CGRectMake(0, 0, 1440, 900);
    CGRect visible = CGRectMake(0, 0, 1440, 900 - 25);
    return [[NSScreen alloc] _initWithScreenNumber:1
                                             frame:frame
                                      visibleFrame:visible
                                backingScaleFactor:sFallbackBackingScaleFactor
                                             depth:0];
}

+ (NSArray<NSScreen *> *)screens
{
    if (sScreens.count > 0) return sScreens;
    /* Off-server fallback: a one-screen list. Stage2 replaces this with the
     * real CGSCopyDisplayList enumeration via +_setScreens:. */
    return @[ [self _fallbackScreen] ];
}

+ (void)_setScreens:(NSArray<NSScreen *> *)screens
{
    sScreens = [screens copy];
}

+ (NSScreen *)mainScreen
{
    /* Stage2: the screen with the key window; here the first screen. */
    return [self screens].firstObject;
}

+ (NSScreen *)deepestScreen
{
    NSScreen *best = nil;
    for (NSScreen *s in [self screens]) {
        if (!best || s->_depth > best->_depth) best = s;
    }
    return best;
}

+ (NSScreen *)_screenForScreenNumber:(NSInteger)screenNumber
{
    for (NSScreen *s in [self screens]) {
        if (s->_screenNumberIvar == screenNumber) return s;
    }
    return nil;
}

+ (CGFloat)_fallbackBackingScaleFactor { return sFallbackBackingScaleFactor; }
+ (void)set_fallbackBackingScaleFactor:(CGFloat)v { sFallbackBackingScaleFactor = v; }

- (CGRect)frame { return _frame; }
- (CGRect)visibleFrame { return _visibleFrame; }
- (CGFloat)backingScaleFactor { return _backingScaleFactor; }
- (NSInteger)depth { return _depth; }
- (NSInteger)_screenNumber { return _screenNumberIvar; }

- (NSInteger)maximumFramesPerSecond { return 60; } /* stage2: from CGDisplay */
- (NSEdgeInsets)safeAreaInsets { return NSEdgeInsetsMake(0, 0, 0, 0); } /* stage2: notch */

- (NSString *)localizedName
{
    /* stage2: IODisplay EDID name. Fallback mirrors AppKit's generic name. */
    return @"Display";
}

- (NSDictionary<NSString *, id> *)deviceDescription
{
    /* AppKit keys: NSScreenNumber, NSDeviceSize, NSDeviceBitsPerSample,
     * NSDeviceColorSpaceName, NSDeviceResolution. colorSpace name is stage2. */
    return @{
        @"NSScreenNumber": @(_screenNumberIvar),
        @"NSDeviceSize": [NSValue valueWithBytes:&_frame.size objCType:@encode(CGSize)],
        @"NSDeviceBitsPerSample": @8,
        @"NSDeviceResolution": [NSValue valueWithBytes:&(CGSize){72.0 * _backingScaleFactor, 72.0 * _backingScaleFactor}
                                              objCType:@encode(CGSize)],
    };
}

/* --- backing-coordinate conversion: exact arithmetic over the scale factor --- */

- (CGRect)convertRectToBacking:(CGRect)rect
{
    CGFloat s = _backingScaleFactor;
    return CGRectMake(rect.origin.x * s, rect.origin.y * s,
                      rect.size.width * s, rect.size.height * s);
}

- (CGRect)convertRectFromBacking:(CGRect)rect
{
    CGFloat s = _backingScaleFactor;
    if (s == 0) s = 1;
    return CGRectMake(rect.origin.x / s, rect.origin.y / s,
                      rect.size.width / s, rect.size.height / s);
}

- (CGRect)backingAlignedRect:(CGRect)rect options:(NSAlignmentOptions)options
{
    /* Round the rect to whole backing pixels, then convert back to points.
     * Default (options == 0) behaves as NSAlignAllEdgesNearest: round each
     * edge to the nearest backing pixel. */
    CGFloat s = _backingScaleFactor;
    if (s == 0) s = 1;
    CGFloat minX = rect.origin.x * s;
    CGFloat minY = rect.origin.y * s;
    CGFloat maxX = (rect.origin.x + rect.size.width) * s;
    CGFloat maxY = (rect.origin.y + rect.size.height) * s;
    minX = round(minX); minY = round(minY);
    maxX = round(maxX); maxY = round(maxY);
    return CGRectMake(minX / s, minY / s, (maxX - minX) / s, (maxY - minY) / s);
}

/* --- equality is by display, not pointer --- */

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSScreen class]]) return NO;
    return ((NSScreen *)object)->_screenNumberIvar == _screenNumberIvar;
}

- (NSUInteger)hash { return (NSUInteger)_screenNumberIvar; }

@end

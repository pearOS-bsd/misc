/*
 * NSImage.m — 1:1 (core). See NSImage.h for the interface evidence.
 *
 * size returns the explicitly-set size (sizeWasExplicitlySet flag) or, failing
 * that, the size of the largest representation — AppKit's documented behaviour.
 * setName: enters the image into the process named-image registry and returns
 * YES; imageNamed: looks it up (bundle / asset-catalog loading is stage2).
 * isTemplate is the _flags template bit. Drawing and rep caching are stage2.
 */
#import "NSImage.h"

@implementation NSImage {
    NSString *_name;
    CGSize _size;
    BOOL _sizeWasExplicitlySet;   /* _flags bit */
    BOOL _isTemplate;             /* _flags bit */
    NSMutableArray *_reps;
}

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self) {
        _reps = [NSMutableArray array];
        _size = size;
        _sizeWasExplicitlySet = !(size.width == 0 && size.height == 0);
    }
    return self;
}

- (instancetype)init { return [self initWithSize:CGSizeZero]; }

- (CGSize)size
{
    if (_sizeWasExplicitlySet) return _size;
    /* derive from the largest representation */
    CGSize best = CGSizeZero;
    for (id<NSImageRepSizing> rep in _reps) {
        CGSize s = [rep size];
        if (s.width * s.height > best.width * best.height) best = s;
    }
    return best;
}

- (void)setSize:(CGSize)size
{
    _size = size;
    _sizeWasExplicitlySet = YES;
}

- (NSString *)name { return _name; }

static NSMutableDictionary<NSString *, NSImage *> *NSImageRegistry(void)
{
    static NSMutableDictionary *reg;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ reg = [NSMutableDictionary dictionary]; });
    return reg;
}

- (BOOL)setName:(NSString *)name
{
    NSMutableDictionary *reg = NSImageRegistry();
    @synchronized (reg) {
        if (_name) [reg removeObjectForKey:_name];
        _name = [name copy];
        if (_name) reg[_name] = self;
    }
    return YES;
}

+ (NSImage *)imageNamed:(NSString *)name
{
    if (name.length == 0) return nil;
    @synchronized (NSImageRegistry()) {
        return NSImageRegistry()[name];
    }
    /* stage2: fall back to bundle / asset-catalog / system symbol lookup */
}

- (BOOL)isTemplate { return _isTemplate; }
- (void)setTemplate:(BOOL)v { _isTemplate = v; }

- (NSArray *)representations { return [_reps copy]; }

- (void)addRepresentation:(id<NSImageRepSizing>)imageRep
{
    if (imageRep) [_reps addObject:imageRep];
}

- (void)addRepresentations:(NSArray<id<NSImageRepSizing>> *)imageReps
{
    if (imageReps) [_reps addObjectsFromArray:imageReps];
}

- (void)removeRepresentation:(id<NSImageRepSizing>)imageRep
{
    [_reps removeObjectIdenticalTo:imageRep];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSImage *c = [[NSImage alloc] initWithSize:_size];
    c->_sizeWasExplicitlySet = _sizeWasExplicitlySet;
    c->_isTemplate = _isTemplate;
    c->_reps = [_reps mutableCopy];
    /* a copy is not registered under the original's name */
    return c;
}

@end

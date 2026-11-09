/*
 * NSGraphicsContext.m — 1:1 (core). See NSGraphicsContext.h for interface evidence.
 *
 * Wraps a CGContextRef + flipped flag. The current context is stored per thread
 * (NSThread threadDictionary), matching AppKit's per-thread current context.
 * -saveGraphicsState pushes the receiver onto a per-thread save stack and calls
 * CGContextSaveGState; -restoreGraphicsState pops and calls CGContextRestoreGState.
 * The class save/restoreGraphicsState operate on the current context. Applying
 * shouldAntialias/patternPhase/compositingOperation to the CGContext is stage2;
 * the values are stored.
 */
#import "NSGraphicsContext.h"

static NSString * const kNSCurrentContextKey = @"NSGraphicsContext.current";
static NSString * const kNSSaveStackKey = @"NSGraphicsContext.saveStack";

@implementation NSGraphicsContext {
    CGContextRef _cgContext;
    BOOL _flipped;
    BOOL _shouldAntialias;
    NSInteger _imageInterpolation;
    CGPoint _patternPhase;
    NSUInteger _compositingOperation;
}

- (instancetype)_initWithCGContext:(CGContextRef)ctx flipped:(BOOL)flipped
{
    self = [super init];
    if (self) {
        _cgContext = ctx ? (CGContextRef)CGContextRetain(ctx) : NULL;
        _flipped = flipped;
        _shouldAntialias = YES;
    }
    return self;
}

- (void)dealloc { if (_cgContext) CGContextRelease(_cgContext); }

+ (NSGraphicsContext *)graphicsContextWithCGContext:(CGContextRef)graphicsPort flipped:(BOOL)flipped
{
    if (!graphicsPort) return nil;
    return [[self alloc] _initWithCGContext:graphicsPort flipped:flipped];
}

+ (NSGraphicsContext *)currentContext
{
    return [NSThread currentThread].threadDictionary[kNSCurrentContextKey];
}

+ (void)setCurrentContext:(NSGraphicsContext *)context
{
    NSMutableDictionary *td = [NSThread currentThread].threadDictionary;
    if (context) td[kNSCurrentContextKey] = context;
    else [td removeObjectForKey:kNSCurrentContextKey];
}

+ (BOOL)currentContextDrawingToScreen { return NO; } /* stage2: window-server contexts */

- (CGContextRef)CGContext { return _cgContext; }
- (BOOL)isFlipped { return _flipped; }
- (BOOL)shouldAntialias { return _shouldAntialias; }
- (void)setShouldAntialias:(BOOL)v { _shouldAntialias = v; if (_cgContext) CGContextSetShouldAntialias(_cgContext, v); }
- (NSInteger)imageInterpolation { return _imageInterpolation; }
- (void)setImageInterpolation:(NSInteger)v { _imageInterpolation = v; }
- (CGPoint)patternPhase { return _patternPhase; }
- (void)setPatternPhase:(CGPoint)v { _patternPhase = v; }
- (NSUInteger)compositingOperation { return _compositingOperation; }
- (void)setCompositingOperation:(NSUInteger)v { _compositingOperation = v; }

- (NSMutableArray *)_saveStack
{
    NSMutableDictionary *td = [NSThread currentThread].threadDictionary;
    NSMutableArray *s = td[kNSSaveStackKey];
    if (!s) { s = [NSMutableArray array]; td[kNSSaveStackKey] = s; }
    return s;
}

- (void)saveGraphicsState
{
    [[self _saveStack] addObject:self];
    if (_cgContext) CGContextSaveGState(_cgContext);
}

- (void)restoreGraphicsState
{
    NSMutableArray *s = [self _saveStack];
    if (s.count > 0) [s removeLastObject];
    if (_cgContext) CGContextRestoreGState(_cgContext);
}

+ (void)saveGraphicsState { [[self currentContext] saveGraphicsState]; }
+ (void)restoreGraphicsState { [[self currentContext] restoreGraphicsState]; }

@end

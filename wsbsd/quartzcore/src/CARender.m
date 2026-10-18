/* The renderer (placeholder until the software compositor is in): -renderInContext: and CARenderer. */
#import "CALayerPrivate.h"
void CARenderLayerTree(CALayer *l, CGContextRef ctx) {}
@implementation CARenderer
{ CALayer *_layer; CGRect _bounds; }
+ (CARenderer *)rendererWithBitmap:(void *)data width:(size_t)w height:(size_t)h bytesPerRow:(size_t)rb options:(NSDictionary *)o { return [[self alloc] init]; }
- (CALayer *)layer { return _layer; }
- (void)setLayer:(CALayer *)l { _layer = l; [l _setContext:YES]; }
- (CGRect)bounds { return _bounds; }
- (void)setBounds:(CGRect)b { _bounds = b; }
- (void)beginFrameAtTime:(CFTimeInterval)t timeStamp:(void *)ts {}
- (CGRect)updateBounds { return _bounds; }
- (void)addUpdateRect:(CGRect)r {}
- (void)render {}
- (CFTimeInterval)nextFrameTime { return INFINITY; }
- (void)endFrame {}
@end
@implementation CADisplayLink
{ id _target; SEL _sel; NSTimer *_timer; BOOL _paused; CFTimeInterval _ts, _dur; NSInteger _fi, _fps; CAFrameRateRange _range; }
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel { CADisplayLink *d = [[self alloc] init]; d->_target = target; d->_sel = sel; d->_dur = 1.0 / 60; return d; }
- (void)addToRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode
{
	if (_timer) return;
	_timer = [NSTimer timerWithTimeInterval:_dur target:self selector:@selector(_tick:) userInfo:nil repeats:YES];
	[rl addTimer:_timer forMode:mode];
}
- (void)_tick:(NSTimer *)t
{
	if (_paused) return;
	_ts = CACurrentMediaTime();
	[_target performSelector:_sel withObject:self];
}
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode { [self invalidate]; }
- (void)invalidate { [_timer invalidate]; _timer = nil; }
- (CFTimeInterval)timestamp { return _ts; }
- (CFTimeInterval)duration { return _dur; }
- (CFTimeInterval)targetTimestamp { return _ts + _dur; }
- (BOOL)isPaused { return _paused; } - (void)setPaused:(BOOL)p { _paused = p; }
- (NSInteger)frameInterval { return _fi ?: 1; } - (void)setFrameInterval:(NSInteger)v { _fi = v; }
- (NSInteger)preferredFramesPerSecond { return _fps; } - (void)setPreferredFramesPerSecond:(NSInteger)v { _fps = v; }
- (CAFrameRateRange)preferredFrameRateRange { return _range; } - (void)setPreferredFrameRateRange:(CAFrameRateRange)r { _range = r; }
@end

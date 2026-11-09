/*
 * NSBitmapImageRep.m — 1:1 (core). See NSBitmapImageRep.h for interface evidence.
 *
 * initWithCGImage: retains the CGImage and derives every metric from CoreGraphics:
 *   pixelsWide/High  <- CGImageGetWidth/Height            (and size in points)
 *   bitsPerSample    <- CGImageGetBitsPerComponent        (inherited ivar)
 *   bitsPerPixel     <- CGImageGetBitsPerPixel
 *   bytesPerRow      <- CGImageGetBytesPerRow
 *   samplesPerPixel  = bitsPerPixel / bitsPerSample
 *   hasAlpha         <- CGImageGetAlphaInfo (inherited)
 *   bitmapFormat     <- alpha-first / non-premultiplied / float flags
 * CGImage-backed reps are non-planar (numberOfPlanes 1). Data decoding and
 * planar buffers are stage2.
 */
#import "NSBitmapImageRep.h"

@implementation NSBitmapImageRep {
    CGImageRef _cgImage;
    NSInteger _bytesPerRow;
    NSInteger _bitsPerPixel;
    NSBitmapFormat _bitmapFormat;
}

- (instancetype)initWithCGImage:(CGImageRef)cgImage
{
    if (!cgImage) return nil;
    self = [super init];
    if (self) {
        _cgImage = (CGImageRef)CGImageRetain(cgImage);

        size_t w = CGImageGetWidth(cgImage), h = CGImageGetHeight(cgImage);
        self.pixelsWide = (NSInteger)w;
        self.pixelsHigh = (NSInteger)h;
        self.size = CGSizeMake((CGFloat)w, (CGFloat)h);
        self.bitsPerSample = (NSInteger)CGImageGetBitsPerComponent(cgImage);
        _bitsPerPixel = (NSInteger)CGImageGetBitsPerPixel(cgImage);
        _bytesPerRow = (NSInteger)CGImageGetBytesPerRow(cgImage);

        CGImageAlphaInfo alpha = CGImageGetAlphaInfo(cgImage);
        BOOL hasAlpha = !(alpha == kCGImageAlphaNone ||
                          alpha == kCGImageAlphaNoneSkipLast ||
                          alpha == kCGImageAlphaNoneSkipFirst);
        self.alpha = hasAlpha;
        self.opaque = !hasAlpha;

        CGBitmapInfo info = CGImageGetBitmapInfo(cgImage);
        NSBitmapFormat fmt = 0;
        if (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaNoneSkipFirst)
            fmt |= NSBitmapFormatAlphaFirst;
        if (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast)
            fmt |= NSBitmapFormatAlphaNonpremultiplied;
        if (info & kCGBitmapFloatComponents)
            fmt |= NSBitmapFormatFloatingPointSamples;
        _bitmapFormat = fmt;
    }
    return self;
}

- (void)dealloc { if (_cgImage) CGImageRelease(_cgImage); }

- (CGImageRef)CGImage { return _cgImage; }
- (NSInteger)bitsPerPixel { return _bitsPerPixel; }
- (NSInteger)bytesPerRow { return _bytesPerRow; }
- (NSInteger)samplesPerPixel
{
    NSInteger bps = self.bitsPerSample;
    return bps > 0 ? _bitsPerPixel / bps : 0;
}
- (NSInteger)bytesPerPlane { return _bytesPerRow * self.pixelsHigh; }
- (BOOL)isPlanar { return NO; }           /* CGImage-backed reps are interleaved */
- (NSInteger)numberOfPlanes { return 1; }
- (NSBitmapFormat)bitmapFormat { return _bitmapFormat; }

@end

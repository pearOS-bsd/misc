/*
 * NSBitmapImageRep.h — 1:1 reimplementation (core). NSImageRep subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSBitmapImageRep : NSImageRep <NSSecureCoding> {
 *       I _bytesPerRow;
 *       {?="bitsPerPixel"b8"isPlanar"b1 …"colorModel"b4 …"bitmapFormat"b3
 *          "cgImageIsPrimary"b1 …} _moreRepFlags;
 *       @"<NSObject>" _backing;  @"NSMutableData" _mutableDataBacking; …
 *   }
 *   -initWithCGImage: -initWithData: -CGImage -bitsPerPixel -samplesPerPixel
 *   -bytesPerRow -bytesPerPlane -isPlanar -numberOfPlanes -bitmapFormat
 *
 * A CGImage-backed concrete representation. initWithCGImage: derives every
 * metric from CoreGraphics (width/height/bitsPerComponent/bitsPerPixel/
 * bytesPerRow/alpha), so the core is exact. Decoding image data (initWithData:,
 * ImageIO), raw planar buffers and TIFF/PNG writing are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSImageRep.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSBitmapFormat) {
    NSBitmapFormatAlphaFirst            = 1 << 0,
    NSBitmapFormatAlphaNonpremultiplied = 1 << 1,
    NSBitmapFormatFloatingPointSamples  = 1 << 2,
};

@interface NSBitmapImageRep : NSImageRep

- (nullable instancetype)initWithCGImage:(CGImageRef)cgImage;

@property (readonly) CGImageRef CGImage;
@property (readonly) NSInteger bitsPerPixel;
@property (readonly) NSInteger samplesPerPixel;
@property (readonly) NSInteger bytesPerRow;
@property (readonly) NSInteger bytesPerPlane;
@property (readonly) NSInteger numberOfPlanes;
@property (readonly, getter=isPlanar) BOOL planar;
@property (readonly) NSBitmapFormat bitmapFormat;

@end

NS_ASSUME_NONNULL_END

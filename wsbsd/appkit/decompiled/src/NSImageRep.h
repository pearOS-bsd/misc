/*
 * NSImageRep.h — 1:1 reimplementation (core). NSObject <NSSecureCoding, NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSImageRep : NSObject <NSSecureCoding, NSCopying, NSCoding> {
 *       @"NSString" _colorSpaceName;
 *       {__repFlags="hasAlpha"b1"isOpaque"b1 …"bitsPerSample"b8 …} _repFlags;
 *       i _pixelsWide;  {CGSize} _size;  i _pixelsHigh;
 *       @"NSMutableArray" _bitmapCache;  os_unfair_lock _bitmapCacheLock;
 *   }
 *   @property (T{CGSize}) size;  (TB,GhasAlpha) alpha;  (TB,GisOpaque) opaque;
 *   size setSize: pixelsWide setPixelsWide: pixelsHigh setPixelsHigh:
 *   bitsPerSample setBitsPerSample: hasAlpha setAlpha: isOpaque setOpaque:
 *   colorSpaceName setColorSpaceName:
 *
 * The abstract base holding an image representation's geometry and pixel
 * metadata. hasAlpha/isOpaque are _repFlags b0/b1 and bitsPerSample is b8-15.
 * -size makes it usable as an NSImage representation. drawInRect:/draw and the
 * concrete subclasses (NSBitmapImageRep, NSPDFImageRep, …) are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImageRep : NSObject <NSCopying>

@property CGSize size;
@property NSInteger pixelsWide;
@property NSInteger pixelsHigh;
@property NSInteger bitsPerSample;
@property (getter=hasAlpha) BOOL alpha;
@property (getter=isOpaque) BOOL opaque;
@property (nullable, copy) NSString *colorSpaceName;

@end

NS_ASSUME_NONNULL_END

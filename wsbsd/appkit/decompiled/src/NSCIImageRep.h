/*
 * NSCIImageRep.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCIImageRep, an NSImageRep that wraps a Core Image CIImage.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCIImageRep_interface.txt. Real ivar: _ciImage.
 *
 * This core reproduces construction (initWithCIImage:/+imageRepWithCIImage:
 * retain the image; -CIImage returns the same object) and the derived geometry:
 * -size is the CIImage's extent size; bitsPerSample stays 0 and the rep is
 * non-opaque (measured). The CoreImage render in -draw/-CGImageForProposedRect:
 * is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSImageRep.h"

@class CIImage;

NS_ASSUME_NONNULL_BEGIN

@interface NSCIImageRep : NSImageRep

+ (instancetype)imageRepWithCIImage:(CIImage *)image;
- (instancetype)initWithCIImage:(CIImage *)image;

@property (readonly, strong) CIImage *CIImage;

@end

NS_ASSUME_NONNULL_END

/*
 * NSCIImageRep.m — behavioral-1:1 core. See the header.
 */

#import "NSCIImageRep.h"
#import <CoreImage/CoreImage.h>

@implementation NSCIImageRep {
    CIImage *_ciImage;
}

+ (instancetype)imageRepWithCIImage:(CIImage *)image { return [[self alloc] initWithCIImage:image]; }

- (instancetype)initWithCIImage:(CIImage *)image
{
    self = [super init];
    if (self) {
        _ciImage = image;
        CGRect extent = image ? [image extent] : CGRectZero;
        self.size = extent.size;   /* geometry derives from the image extent */
    }
    return self;
}

- (CIImage *)CIImage { return _ciImage; }

- (BOOL)draw
{
    /* TODO(stage2): render _ciImage through a CIContext into the current
       graphics context. */
    return YES;
}

@end

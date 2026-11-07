/* NSImageView.m — 1:1 (core). Delegates to NSImageCell. Evidence ../evidence/image. */
#import "NSImageView.h"

@implementation NSImageView

+ (Class)cellClass { return [NSImageCell class]; }

- (NSImageCell *)imageCell { return (NSImageCell *)self.cell; }

- (NSImageAlignment)imageAlignment { return [self.imageCell imageAlignment]; }
- (void)setImageAlignment:(NSImageAlignment)a { [self.imageCell setImageAlignment:a]; }
- (NSImageScaling)imageScaling { return [self.imageCell imageScaling]; }
- (void)setImageScaling:(NSImageScaling)s { [self.imageCell setImageScaling:s]; }
- (NSImageFrameStyle)imageFrameStyle { return [self.imageCell imageFrameStyle]; }
- (void)setImageFrameStyle:(NSImageFrameStyle)f { [self.imageCell setImageFrameStyle:f]; }
- (id)image { return [self.imageCell image]; }
- (void)setImage:(id)image { [self.imageCell setImage:image]; }

@end

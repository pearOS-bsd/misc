/*
 * NSImageView.h — 1:1 reimplementation (core). NSControl backed by NSImageCell;
 * props delegate to the cell (imageScaling 0x184fba83c -> [cell imageScaling],
 * evidence ../evidence/image).
 */
#import "NSControl.h"
#import "NSImageCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSImageView : NSControl
@property NSImageAlignment imageAlignment;
@property NSImageScaling imageScaling;
@property NSImageFrameStyle imageFrameStyle;
@property (nullable, strong) id image;
@end

NS_ASSUME_NONNULL_END

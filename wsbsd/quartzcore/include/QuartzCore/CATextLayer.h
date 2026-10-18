/* <QuartzCore/CATextLayer.h> */
#ifndef WSBSD_CATEXTLAYER_H
#define WSBSD_CATEXTLAYER_H
#import <QuartzCore/CALayer.h>
typedef NSString *CATextLayerTruncationMode NS_TYPED_ENUM;
typedef NSString *CATextLayerAlignmentMode NS_TYPED_ENUM;
@interface CATextLayer : CALayer
@property(copy) id string;
@property CFTypeRef font;
@property CGFloat fontSize;
@property CGColorRef foregroundColor;
@property(getter=isWrapped) BOOL wrapped;
@property(copy) CATextLayerTruncationMode truncationMode;
@property(copy) CATextLayerAlignmentMode alignmentMode;
@property BOOL allowsFontSubpixelQuantization;
@end
CA_EXTERN CATextLayerTruncationMode const kCATruncationNone;
CA_EXTERN CATextLayerTruncationMode const kCATruncationStart;
CA_EXTERN CATextLayerTruncationMode const kCATruncationEnd;
CA_EXTERN CATextLayerTruncationMode const kCATruncationMiddle;
CA_EXTERN CATextLayerAlignmentMode const kCAAlignmentNatural;
CA_EXTERN CATextLayerAlignmentMode const kCAAlignmentLeft;
CA_EXTERN CATextLayerAlignmentMode const kCAAlignmentRight;
CA_EXTERN CATextLayerAlignmentMode const kCAAlignmentCenter;
CA_EXTERN CATextLayerAlignmentMode const kCAAlignmentJustified;
#endif

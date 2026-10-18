/* <QuartzCore/CAGradientLayer.h> */
#ifndef WSBSD_CAGRADIENTLAYER_H
#define WSBSD_CAGRADIENTLAYER_H
#import <QuartzCore/CALayer.h>
typedef NSString *CAGradientLayerType NS_TYPED_ENUM;
@interface CAGradientLayer : CALayer
@property(copy) NSArray *colors;
@property(copy) NSArray<NSNumber *> *locations;
@property CGPoint startPoint;
@property CGPoint endPoint;
@property(copy) CAGradientLayerType type;
@end
CA_EXTERN CAGradientLayerType const kCAGradientLayerAxial;
CA_EXTERN CAGradientLayerType const kCAGradientLayerRadial;
CA_EXTERN CAGradientLayerType const kCAGradientLayerConic;
#endif

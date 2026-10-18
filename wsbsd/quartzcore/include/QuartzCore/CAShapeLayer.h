/* <QuartzCore/CAShapeLayer.h> */
#ifndef WSBSD_CASHAPELAYER_H
#define WSBSD_CASHAPELAYER_H
#import <QuartzCore/CALayer.h>
typedef NSString *CAShapeLayerFillRule NS_TYPED_ENUM;
typedef NSString *CAShapeLayerLineJoin NS_TYPED_ENUM;
typedef NSString *CAShapeLayerLineCap NS_TYPED_ENUM;
@interface CAShapeLayer : CALayer
@property CGPathRef path;
@property CGColorRef fillColor;
@property(copy) CAShapeLayerFillRule fillRule;
@property CGColorRef strokeColor;
@property CGFloat strokeStart;
@property CGFloat strokeEnd;
@property CGFloat lineWidth;
@property CGFloat miterLimit;
@property(copy) CAShapeLayerLineCap lineCap;
@property(copy) CAShapeLayerLineJoin lineJoin;
@property CGFloat lineDashPhase;
@property(copy) NSArray<NSNumber *> *lineDashPattern;
@end
CA_EXTERN CAShapeLayerFillRule const kCAFillRuleNonZero;
CA_EXTERN CAShapeLayerFillRule const kCAFillRuleEvenOdd;
CA_EXTERN CAShapeLayerLineJoin const kCALineJoinMiter;
CA_EXTERN CAShapeLayerLineJoin const kCALineJoinRound;
CA_EXTERN CAShapeLayerLineJoin const kCALineJoinBevel;
CA_EXTERN CAShapeLayerLineCap const kCALineCapButt;
CA_EXTERN CAShapeLayerLineCap const kCALineCapRound;
CA_EXTERN CAShapeLayerLineCap const kCALineCapSquare;
#endif

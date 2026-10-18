/* <QuartzCore/CAMediaTimingFunction.h>: a cubic Bezier timing curve (0,0) (c1x,c1y) (c2x,c2y) (1,1). */
#ifndef WSBSD_CAMEDIATIMINGFUNCTION_H
#define WSBSD_CAMEDIATIMINGFUNCTION_H
#import <QuartzCore/CAMediaTiming.h>

typedef NSString *CAMediaTimingFunctionName NS_TYPED_ENUM;

@interface CAMediaTimingFunction : NSObject <NSSecureCoding>
{
@private
	float _c[4];
}
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name;
+ (instancetype)functionWithControlPoints:(float)c1x :(float)c1y :(float)c2x :(float)c2y;
- (instancetype)initWithControlPoints:(float)c1x :(float)c1y :(float)c2x :(float)c2y;
- (void)getControlPointAtIndex:(size_t)idx values:(float[2])ptr;
@end

CA_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionLinear;
CA_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseIn;
CA_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseOut;
CA_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionEaseInEaseOut;
CA_EXTERN CAMediaTimingFunctionName const kCAMediaTimingFunctionDefault;
#endif

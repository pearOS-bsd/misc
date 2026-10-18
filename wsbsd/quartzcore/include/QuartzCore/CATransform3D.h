/* <QuartzCore/CATransform3D.h>: the 4x4 transformation matrix of Core Animation (row vectors: a point is multiplied from the left, the first transformation applied is the left factor of a concatenation). */
#ifndef WSBSD_CATRANSFORM3D_H
#define WSBSD_CATRANSFORM3D_H
#import <QuartzCore/CABase.h>
#ifdef __OBJC__
#import <Foundation/NSValue.h>
#endif

CA_EXTERN_C_BEGIN
struct CATransform3D
{
	CGFloat m11, m12, m13, m14;
	CGFloat m21, m22, m23, m24;
	CGFloat m31, m32, m33, m34;
	CGFloat m41, m42, m43, m44;
};
typedef struct CATransform3D CATransform3D;

CA_EXTERN const CATransform3D CATransform3DIdentity;
CA_EXTERN bool CATransform3DIsIdentity(CATransform3D t);
CA_EXTERN bool CATransform3DEqualToTransform(CATransform3D a, CATransform3D b);
CA_EXTERN CATransform3D CATransform3DMakeTranslation(CGFloat tx, CGFloat ty, CGFloat tz);
CA_EXTERN CATransform3D CATransform3DMakeScale(CGFloat sx, CGFloat sy, CGFloat sz);
CA_EXTERN CATransform3D CATransform3DMakeRotation(CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
CA_EXTERN CATransform3D CATransform3DTranslate(CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz);
CA_EXTERN CATransform3D CATransform3DScale(CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz);
CA_EXTERN CATransform3D CATransform3DRotate(CATransform3D t, CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
CA_EXTERN CATransform3D CATransform3DConcat(CATransform3D a, CATransform3D b);
CA_EXTERN CATransform3D CATransform3DInvert(CATransform3D t);
CA_EXTERN CATransform3D CATransform3DMakeAffineTransform(CGAffineTransform m);
CA_EXTERN bool CATransform3DIsAffine(CATransform3D t);
CA_EXTERN CGAffineTransform CATransform3DGetAffineTransform(CATransform3D t);
CA_EXTERN_C_END

#ifdef __OBJC__
@interface NSValue (CATransform3DAdditions)
+ (NSValue *)valueWithCATransform3D:(CATransform3D)t;
@property(readonly) CATransform3D CATransform3DValue;
@end
#endif
#endif

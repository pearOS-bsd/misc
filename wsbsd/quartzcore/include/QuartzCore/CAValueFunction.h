/* <QuartzCore/CAValueFunction.h>: maps the scalar of an animation onto a matrix (rotate, scale, translate). */
#ifndef WSBSD_CAVALUEFUNCTION_H
#define WSBSD_CAVALUEFUNCTION_H
#import <QuartzCore/CABase.h>
#import <Foundation/Foundation.h>

typedef NSString *CAValueFunctionName NS_TYPED_ENUM;

@interface CAValueFunction : NSObject <NSSecureCoding>
{
@protected
	NSString *_string;
	void *_impl;
}
+ (instancetype)functionWithName:(CAValueFunctionName)name;
@property(readonly) CAValueFunctionName name;
@end

CA_EXTERN CAValueFunctionName const kCAValueFunctionRotateX;
CA_EXTERN CAValueFunctionName const kCAValueFunctionRotateY;
CA_EXTERN CAValueFunctionName const kCAValueFunctionRotateZ;
CA_EXTERN CAValueFunctionName const kCAValueFunctionScale;
CA_EXTERN CAValueFunctionName const kCAValueFunctionScaleX;
CA_EXTERN CAValueFunctionName const kCAValueFunctionScaleY;
CA_EXTERN CAValueFunctionName const kCAValueFunctionScaleZ;
CA_EXTERN CAValueFunctionName const kCAValueFunctionTranslate;
CA_EXTERN CAValueFunctionName const kCAValueFunctionTranslateX;
CA_EXTERN CAValueFunctionName const kCAValueFunctionTranslateY;
CA_EXTERN CAValueFunctionName const kCAValueFunctionTranslateZ;
#endif

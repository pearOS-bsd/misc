/* <QuartzCore/CAMediaTiming.h>: the timing properties shared by layers and animations. */
#ifndef WSBSD_CAMEDIATIMING_H
#define WSBSD_CAMEDIATIMING_H
#import <QuartzCore/CABase.h>
#import <Foundation/Foundation.h>

typedef NSString *CAMediaTimingFillMode NS_TYPED_ENUM;

@protocol CAMediaTiming
@property CFTimeInterval beginTime;
@property CFTimeInterval duration;
@property float speed;
@property CFTimeInterval timeOffset;
@property float repeatCount;
@property CFTimeInterval repeatDuration;
@property BOOL autoreverses;
@property(copy) CAMediaTimingFillMode fillMode;
@end

CA_EXTERN CAMediaTimingFillMode const kCAFillModeForwards;
CA_EXTERN CAMediaTimingFillMode const kCAFillModeBackwards;
CA_EXTERN CAMediaTimingFillMode const kCAFillModeBoth;
CA_EXTERN CAMediaTimingFillMode const kCAFillModeRemoved;
#endif

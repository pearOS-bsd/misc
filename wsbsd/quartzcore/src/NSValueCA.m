/* NSValue (CATransform3DAdditions) */
#import <QuartzCore/CATransform3D.h>
@implementation NSValue (CATransform3DAdditions)
+ (NSValue *)valueWithCATransform3D:(CATransform3D)t { return [NSValue valueWithBytes:&t objCType:@encode(CATransform3D)]; }
- (CATransform3D)CATransform3DValue { CATransform3D t = CATransform3DIdentity; [self getValue:&t]; return t; }
@end

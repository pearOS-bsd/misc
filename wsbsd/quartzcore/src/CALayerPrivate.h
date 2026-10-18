#ifndef WSBSD_CALAYERPRIVATE_H
#define WSBSD_CALAYERPRIVATE_H
#import "CAInternal.h"

@interface CAMediaTimingFunction ()
- (float)_solve:(float)x;
@end
BOOL CAMapAnimationTime(CAAnimation *a, double *t, int *iteration);
bool CAAnimationTiming(CAAnimation *a, CATiming *t);
void CAKeyframeApply(CAKeyframeAnimation *k, CFTimeInterval time, id pres, id model);

/* the layer side of KVC: key paths with components (position.x, transform.rotation.z ...) */
id CALayerValueForKeyPath(CALayer *l, NSString *kp);
void CALayerSetValueForKeyPath(CALayer *l, NSString *kp, id v);
@interface CAAnimation ()
- (void)_copyInto:(CAAnimation *)c;
@end
@interface CABasicAnimation ()
- (double)_timeFunction:(double)t;
- (BOOL)_roundsToInteger;
@end
void CALayerCommitAnimations(void);
void CALayerRefreshPresentations(void);
void CARenderLayerTree(CALayer *l, CGContextRef ctx);
@interface CALayer ()
- (id)_actionForPropertyChange:(NSString *)key flags:(unsigned)flags;
- (void)_runAction:(id)action forKey:(NSString *)key;
- (CAAnimation *)_implicitAnimationForKeyPath:(NSString *)key;
- (CFTimeInterval)_localTime;
- (void)_commitAnimations;
- (CALayer *)_presentationTreeAtTime:(CFTimeInterval)t;
- (NSArray *)_sublayerArray;
- (CATransform3D)_localToSuperMatrix;
- (void)_markCommitted;
- (void)_refreshPresentation;
- (void)_boundsChanged;
- (void)_sublayersChanged;
- (void)_copyPropertiesFrom:(CALayer *)o;
- (BOOL)_drawsContents;
- (void)_configureImplicit:(CAAnimation *)a;
@end
@interface CATransaction ()
+ (void)_wsbsdFlushImplicit;
@end
#endif

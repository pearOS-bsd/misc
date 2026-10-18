/* On macOS the real QuartzCore is loaded into every process: for the tests this implementation is built under other names (WS prefix) so that both can run side by side. */
#ifndef WSBSD_RENAME_H
#define WSBSD_RENAME_H
#define CALayer WSCALayer
#define CAShapeLayer WSCAShapeLayer
#define CATextLayer WSCATextLayer
#define CAGradientLayer WSCAGradientLayer
#define CATransformLayer WSCATransformLayer
#define CAReplicatorLayer WSCAReplicatorLayer
#define CAScrollLayer WSCAScrollLayer
#define CATiledLayer WSCATiledLayer
#define CAEmitterLayer WSCAEmitterLayer
#define CAEmitterCell WSCAEmitterCell
#define CAAnimation WSCAAnimation
#define CAPropertyAnimation WSCAPropertyAnimation
#define CABasicAnimation WSCABasicAnimation
#define CASpringAnimation WSCASpringAnimation
#define CAKeyframeAnimation WSCAKeyframeAnimation
#define CATransition WSCATransition
#define CAAnimationGroup WSCAAnimationGroup
#define CAMediaTimingFunction WSCAMediaTimingFunction
#define CAValueFunction WSCAValueFunction
#define CATransaction WSCATransaction
#define CARenderer WSCARenderer
#define CADisplayLink WSCADisplayLink
#define CAMediaTiming WSCAMediaTiming
#define CAAction WSCAAction
#define CALayerDelegate WSCALayerDelegate
#define CALayoutManager WSCALayoutManager
#define CAAnimationDelegate WSCAAnimationDelegate
#define valueWithCATransform3D WSvalueWithCATransform3D
#define CATransform3DValue WSCATransform3DValue
#endif

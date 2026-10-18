/* <QuartzCore/CALayer.h>: the layer tree. A layer keeps its model values; the presentation layer (-presentationLayer) holds the values with the running animations applied. */
#ifndef WSBSD_CALAYER_H
#define WSBSD_CALAYER_H
#import <QuartzCore/CAMediaTiming.h>
#import <QuartzCore/CATransform3D.h>
#import <QuartzCore/CAFrameRateRange.h>
@class CAAnimation, CALayer;
@protocol CAAction, CALayerDelegate, CALayoutManager;

typedef NSString *CALayerContentsGravity NS_TYPED_ENUM;
typedef NSString *CALayerContentsFormat NS_TYPED_ENUM;
typedef NSString *CALayerContentsFilter NS_TYPED_ENUM;
typedef NSString *CALayerCornerCurve NS_TYPED_ENUM;
typedef NSString *CAToneMapMode NS_TYPED_ENUM;
typedef NSString *CADynamicRange NS_TYPED_ENUM;

typedef NS_OPTIONS(unsigned int, CAAutoresizingMask) {
	kCALayerNotSizable = 0,
	kCALayerMinXMargin = 1U << 0,
	kCALayerWidthSizable = 1U << 1,
	kCALayerMaxXMargin = 1U << 2,
	kCALayerMinYMargin = 1U << 3,
	kCALayerHeightSizable = 1U << 4,
	kCALayerMaxYMargin = 1U << 5
};
typedef NS_OPTIONS(unsigned int, CAEdgeAntialiasingMask) {
	kCALayerLeftEdge = 1U << 0,
	kCALayerRightEdge = 1U << 1,
	kCALayerBottomEdge = 1U << 2,
	kCALayerTopEdge = 1U << 3,
};
typedef NS_OPTIONS(NSUInteger, CACornerMask) {
	kCALayerMinXMinYCorner = 1U << 0,
	kCALayerMaxXMinYCorner = 1U << 1,
	kCALayerMinXMaxYCorner = 1U << 2,
	kCALayerMaxXMaxYCorner = 1U << 3,
};

CA_EXTERN CAToneMapMode const CAToneMapModeAutomatic;
CA_EXTERN CAToneMapMode const CAToneMapModeNever;
CA_EXTERN CAToneMapMode const CAToneMapModeIfSupported;
CA_EXTERN CADynamicRange const CADynamicRangeAutomatic;
CA_EXTERN CADynamicRange const CADynamicRangeStandard;
CA_EXTERN CADynamicRange const CADynamicRangeConstrainedHigh;
CA_EXTERN CADynamicRange const CADynamicRangeHigh;

@interface CALayer : NSObject <NSSecureCoding, CAMediaTiming>
{
@private
	void *_state;
}
+ (instancetype)layer;
- (instancetype)init;
- (instancetype)initWithLayer:(id)layer;
- (instancetype)presentationLayer;
- (instancetype)modelLayer;
+ (id)defaultValueForKey:(NSString *)key;
+ (BOOL)needsDisplayForKey:(NSString *)key;
- (BOOL)shouldArchiveValueForKey:(NSString *)key;

@property CGRect bounds;
@property CGPoint position;
@property CGFloat zPosition;
@property CGPoint anchorPoint;
@property CGFloat anchorPointZ;
@property CATransform3D transform;
- (CGAffineTransform)affineTransform;
- (void)setAffineTransform:(CGAffineTransform)m;
@property CGRect frame;
@property(getter=isHidden) BOOL hidden;
@property(getter=isDoubleSided) BOOL doubleSided;
@property(getter=isGeometryFlipped) BOOL geometryFlipped;
- (BOOL)contentsAreFlipped;

@property(readonly) CALayer *superlayer;
- (void)removeFromSuperlayer;
@property(copy) NSArray<CALayer *> *sublayers;
- (void)addSublayer:(CALayer *)layer;
- (void)insertSublayer:(CALayer *)layer atIndex:(unsigned)idx;
- (void)insertSublayer:(CALayer *)layer below:(CALayer *)sibling;
- (void)insertSublayer:(CALayer *)layer above:(CALayer *)sibling;
- (void)replaceSublayer:(CALayer *)oldLayer with:(CALayer *)newLayer;
@property CATransform3D sublayerTransform;
@property(strong) CALayer *mask;
@property BOOL masksToBounds;

- (CGPoint)convertPoint:(CGPoint)p fromLayer:(CALayer *)l;
- (CGPoint)convertPoint:(CGPoint)p toLayer:(CALayer *)l;
- (CGRect)convertRect:(CGRect)r fromLayer:(CALayer *)l;
- (CGRect)convertRect:(CGRect)r toLayer:(CALayer *)l;
- (CFTimeInterval)convertTime:(CFTimeInterval)t fromLayer:(CALayer *)l;
- (CFTimeInterval)convertTime:(CFTimeInterval)t toLayer:(CALayer *)l;
- (CALayer *)hitTest:(CGPoint)p;
- (BOOL)containsPoint:(CGPoint)p;

@property(strong) id contents;
@property CGRect contentsRect;
@property(copy) CALayerContentsGravity contentsGravity;
@property CGFloat contentsScale;
@property CGRect contentsCenter;
@property(copy) CALayerContentsFormat contentsFormat;
@property BOOL wantsExtendedDynamicRangeContent;
@property(copy) CAToneMapMode toneMapMode;
@property(copy) CADynamicRange preferredDynamicRange;
@property CGFloat contentsHeadroom;
@property BOOL wantsDynamicContentScaling;
@property(copy) CALayerContentsFilter minificationFilter;
@property(copy) CALayerContentsFilter magnificationFilter;
@property float minificationFilterBias;
@property(getter=isOpaque) BOOL opaque;
- (void)display;
- (void)setNeedsDisplay;
- (void)setNeedsDisplayInRect:(CGRect)r;
- (BOOL)needsDisplay;
- (void)displayIfNeeded;
@property BOOL needsDisplayOnBoundsChange;
@property BOOL drawsAsynchronously;
- (void)drawInContext:(CGContextRef)ctx;
- (void)renderInContext:(CGContextRef)ctx;
@property CAEdgeAntialiasingMask edgeAntialiasingMask;
@property BOOL allowsEdgeAntialiasing;

@property CGColorRef backgroundColor;
@property CGFloat cornerRadius;
@property CACornerMask maskedCorners;
@property(copy) CALayerCornerCurve cornerCurve;
+ (CGFloat)cornerCurveExpansionFactor:(CALayerCornerCurve)curve;
@property CGFloat borderWidth;
@property CGColorRef borderColor;
@property float opacity;
@property BOOL allowsGroupOpacity;
@property(strong) id compositingFilter;
@property(copy) NSArray *filters;
@property(copy) NSArray *backgroundFilters;
@property BOOL shouldRasterize;
@property CGFloat rasterizationScale;
@property CGColorRef shadowColor;
@property float shadowOpacity;
@property CGSize shadowOffset;
@property CGFloat shadowRadius;
@property CGPathRef shadowPath;

@property CAAutoresizingMask autoresizingMask;
@property(strong) id<CALayoutManager> layoutManager;
- (CGSize)preferredFrameSize;
- (void)setNeedsLayout;
- (BOOL)needsLayout;
- (void)layoutIfNeeded;
- (void)layoutSublayers;
- (void)resizeSublayersWithOldSize:(CGSize)size;
- (void)resizeWithOldSuperlayerSize:(CGSize)size;

+ (id<CAAction>)defaultActionForKey:(NSString *)event;
- (id<CAAction>)actionForKey:(NSString *)event;
@property(copy) NSDictionary<NSString *, id<CAAction>> *actions;
- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key;
- (void)removeAllAnimations;
- (void)removeAnimationForKey:(NSString *)key;
- (NSArray<NSString *> *)animationKeys;
- (CAAnimation *)animationForKey:(NSString *)key;

@property(copy) NSString *name;
@property(weak) id<CALayerDelegate> delegate;
@property(copy) NSDictionary *style;
@end

@protocol CALayoutManager <NSObject>
@optional
- (CGSize)preferredSizeOfLayer:(CALayer *)layer;
- (void)invalidateLayoutOfLayer:(CALayer *)layer;
- (void)layoutSublayersOfLayer:(CALayer *)layer;
@end

@protocol CAAction
- (void)runActionForKey:(NSString *)event object:(id)anObject arguments:(NSDictionary *)dict;
@end

@interface NSNull (CAActionAdditions) <CAAction>
@end

@protocol CALayerDelegate <NSObject>
@optional
- (void)displayLayer:(CALayer *)layer;
- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;
- (void)layerWillDraw:(CALayer *)layer;
- (void)layoutSublayersOfLayer:(CALayer *)layer;
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event;
@end

CA_EXTERN CALayerContentsGravity const kCAGravityCenter;
CA_EXTERN CALayerContentsGravity const kCAGravityTop;
CA_EXTERN CALayerContentsGravity const kCAGravityBottom;
CA_EXTERN CALayerContentsGravity const kCAGravityLeft;
CA_EXTERN CALayerContentsGravity const kCAGravityRight;
CA_EXTERN CALayerContentsGravity const kCAGravityTopLeft;
CA_EXTERN CALayerContentsGravity const kCAGravityTopRight;
CA_EXTERN CALayerContentsGravity const kCAGravityBottomLeft;
CA_EXTERN CALayerContentsGravity const kCAGravityBottomRight;
CA_EXTERN CALayerContentsGravity const kCAGravityResize;
CA_EXTERN CALayerContentsGravity const kCAGravityResizeAspect;
CA_EXTERN CALayerContentsGravity const kCAGravityResizeAspectFill;
CA_EXTERN CALayerContentsFormat const kCAContentsFormatRGBA8Uint;
CA_EXTERN CALayerContentsFormat const kCAContentsFormatRGBA16Float;
CA_EXTERN CALayerContentsFormat const kCAContentsFormatGray8Uint;
CA_EXTERN CALayerContentsFormat const kCAContentsFormatAutomatic;
CA_EXTERN CALayerContentsFilter const kCAFilterNearest;
CA_EXTERN CALayerContentsFilter const kCAFilterLinear;
CA_EXTERN CALayerContentsFilter const kCAFilterTrilinear;
CA_EXTERN CALayerCornerCurve const kCACornerCurveCircular;
CA_EXTERN CALayerCornerCurve const kCACornerCurveContinuous;
CA_EXTERN NSString *const kCAOnOrderIn;
CA_EXTERN NSString *const kCAOnOrderOut;
CA_EXTERN NSString *const kCATransition;
#endif

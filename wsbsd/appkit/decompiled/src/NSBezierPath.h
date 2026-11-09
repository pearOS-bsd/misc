/*
 * NSBezierPath.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSBezierPath : NSObject <NSCopying, NSSecureCoding> {
 *       d _lineWidth; d _miterLimit; d _flatness;
 *       ^d _dashedLinePattern; Q _dashedLineCount; d _dashedLinePhase;
 *       ^{CGPath=} _cgPath;                       // CGPathRef backing store
 *       ^{?=Q{CGPoint}{CGPoint}{CGPoint}} _localPathCache;
 *       {?="_flags"b8"_pathState"b2"_unused"b22} _bpFlags;
 *   }
 *   @property (T^{CGPath=}) CGPath;  @property (Td) lineWidth/miterLimit/flatness;
 *   @property (TQ) lineCapStyle/lineJoinStyle/windingRule;
 *   @property (TB,R,GisEmpty) empty;  (T{CGPoint}) currentPoint;
 *   @property (T{CGRect}) bounds/controlPointBounds;  (Tq,R) elementCount;
 *
 * Modern NSBezierPath is a thin wrapper over a CGPath (the `_cgPath` ivar). The
 * element API, the geometry queries and the convenience constructors are all
 * expressed over CoreGraphics, so this core is exact on BSD. Dashing
 * (_dashedLine*), glyph paths, flattening/reversing and drawing (stroke/fill,
 * which need a graphics context) are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSBezierPathElement) {
    NSBezierPathElementMoveTo = 0,
    NSBezierPathElementLineTo = 1,
    NSBezierPathElementCurveTo = 2,
    NSBezierPathElementClosePath = 3,
};

typedef NS_ENUM(NSUInteger, NSLineCapStyle)  { NSLineCapStyleButt = 0, NSLineCapStyleRound = 1, NSLineCapStyleSquare = 2 };
typedef NS_ENUM(NSUInteger, NSLineJoinStyle) { NSLineJoinStyleMiter = 0, NSLineJoinStyleRound = 1, NSLineJoinStyleBevel = 2 };
typedef NS_ENUM(NSUInteger, NSWindingRule)   { NSWindingRuleNonZero = 0, NSWindingRuleEvenOdd = 1 };

@interface NSBezierPath : NSObject <NSCopying>

+ (NSBezierPath *)bezierPath;
+ (NSBezierPath *)bezierPathWithRect:(CGRect)rect;
+ (NSBezierPath *)bezierPathWithOvalInRect:(CGRect)rect;
+ (NSBezierPath *)bezierPathWithRoundedRect:(CGRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
+ (NSBezierPath *)bezierPathWithCGPath:(CGPathRef)cgPath;

/* class defaults */
@property (class) CGFloat defaultLineWidth;
@property (class) CGFloat defaultFlatness;
@property (class) CGFloat defaultMiterLimit;
@property (class) NSLineCapStyle defaultLineCapStyle;
@property (class) NSLineJoinStyle defaultLineJoinStyle;
@property (class) NSWindingRule defaultWindingRule;

/* construction */
- (void)moveToPoint:(CGPoint)point;
- (void)lineToPoint:(CGPoint)point;
- (void)curveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)cp1 controlPoint2:(CGPoint)cp2;
- (void)closePath;
- (void)removeAllPoints;

/* appending */
- (void)appendBezierPath:(NSBezierPath *)path;
- (void)appendBezierPathWithRect:(CGRect)rect;
- (void)appendBezierPathWithOvalInRect:(CGRect)rect;
- (void)appendBezierPathWithPoints:(const CGPoint *)points count:(NSInteger)count;
- (void)appendBezierPathWithCGPath:(CGPathRef)cgPath;

/* transform */
- (void)transformUsingAffineTransform:(NSAffineTransform *)transform;

/* queries */
@property (readonly, getter=isEmpty) BOOL empty;
@property (readonly) CGPoint currentPoint;
@property (readonly) CGRect bounds;
@property (readonly) CGRect controlPointBounds;
@property (readonly) NSInteger elementCount;
- (NSBezierPathElement)elementAtIndex:(NSInteger)index;
- (NSBezierPathElement)elementAtIndex:(NSInteger)index associatedPoints:(nullable CGPoint *)points;

@property CGFloat lineWidth;
@property CGFloat miterLimit;
@property CGFloat flatness;
@property NSLineCapStyle lineCapStyle;
@property NSLineJoinStyle lineJoinStyle;
@property NSWindingRule windingRule;
@property (readonly) CGPathRef CGPath;

@end

NS_ASSUME_NONNULL_END

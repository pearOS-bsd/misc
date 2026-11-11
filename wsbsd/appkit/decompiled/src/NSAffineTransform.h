/*
 * NSAffineTransform.h — 1:1 reimplementation of AppKit's
 * NSAffineTransform (NSAppKitAdditions) category.
 *
 * The NSAffineTransform *class* itself (transformStruct, translateXBy:yBy:,
 * scaleBy:/scaleXBy:yBy:, rotateByDegrees:/rotateByRadians:, appendTransform:/
 * prependTransform:, invert, transformPoint:, transformSize:, NSCopying/
 * NSSecureCoding) is a **Foundation** class — on the BSD target it comes from
 * swift-corelibs-foundation, on the host from Foundation.framework. AppKit does
 * not redefine the class; it adds this category of drawing / CoreGraphics-bridge
 * conveniences. So the 1:1 unit of work here is the category, layered on top of
 * the Foundation base (never reimplementing the base).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e,
 * via `ipsw dyld macho <dsc> AppKit --objc`), saved in
 * evidence/-NSAffineTransform_interface.txt:
 *
 *   @interface NSAffineTransform (NSAppKitAdditions)
 *   + transformWithCGAffineTransform:
 *   - isIdentity
 *   - set
 *   - reset
 *   - CGAffineTransform
 *   - concat
 *   - inverseTransformPoint:
 *   - inverseTransformRect:
 *   - inverseTransformSize:
 *   - isRectilinear
 *   - isSingular
 *   - setCGAffineTransform:
 *   - transformBezierPath:
 *   - transformRect:
 *   @end
 *
 * Behaviour is transcribed from the documented/stable semantics of these
 * methods (CoreGraphics bridge + CGRectApplyAffineTransform / matrix predicates);
 * -set and -concat touch the current NSGraphicsContext CTM and are annotated
 * stage2 where the exact window-server base-CTM handling lives.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class NSBezierPath;

NS_ASSUME_NONNULL_BEGIN

@interface NSAffineTransform (NSAppKitAdditions)

/* CoreGraphics bridge */
+ (NSAffineTransform *)transformWithCGAffineTransform:(CGAffineTransform)aTransform;
@property (readonly) CGAffineTransform CGAffineTransform;
- (void)setCGAffineTransform:(CGAffineTransform)aTransform;

/* matrix predicates */
@property (readonly, getter=isIdentity)   BOOL identity;
@property (readonly, getter=isRectilinear) BOOL rectilinear;
@property (readonly, getter=isSingular)   BOOL singular;

/* reset to identity */
- (void)reset;

/* apply to the current graphics context (stage2: exact base-CTM semantics) */
- (void)set;
- (void)concat;

/* inverse mapping */
- (NSPoint)inverseTransformPoint:(NSPoint)aPoint;
- (NSSize)inverseTransformSize:(NSSize)aSize;
- (NSRect)inverseTransformRect:(NSRect)aRect;

/* forward rect / bezier mapping */
- (NSRect)transformRect:(NSRect)aRect;
- (nullable NSBezierPath *)transformBezierPath:(NSBezierPath *)aPath;

@end

NS_ASSUME_NONNULL_END

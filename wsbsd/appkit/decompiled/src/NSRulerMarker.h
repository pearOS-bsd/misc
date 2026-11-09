/*
 * NSRulerMarker.h — 1:1 reimplementation (core). NSObject <NSCopying, NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSRulerMarker : NSObject <NSCopying, NSCoding> {
 *       @"NSImage" _image;  {CGPoint} _imageOrigin;  @ _representedObject;
 *       @"NSRulerView" _ruler;  d _location;
 *       {__rFlags="movable"b1"removable"b1"dragging"b1"pinned"b1 …} _rFlags;
 *       … (tracking ivars)
 *   }
 *   -initWithRulerView:markerLocation:image:imageOrigin: -ruler -markerLocation
 *   -setMarkerLocation: -image -imageOrigin -isMovable -isRemovable -representedObject
 *
 * A marker on an NSRulerView (a tab stop, margin, etc.). The core holds the
 * owning ruler, location, image + image origin, the movable/removable flags
 * (_rFlags b0/b1) and a represented object. The interactive drag tracking is
 * stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSRulerMarker : NSObject <NSCopying>

- (instancetype)initWithRulerView:(id)ruler
                   markerLocation:(CGFloat)location
                            image:(id)image
                      imageOrigin:(CGPoint)imageOrigin;

@property (nullable, readonly, weak) id ruler;   /* NSRulerView */
@property CGFloat markerLocation;
@property (strong) id image;                      /* NSImage */
@property CGPoint imageOrigin;
@property (getter=isMovable) BOOL movable;
@property (getter=isRemovable) BOOL removable;
@property (nullable, strong) id representedObject;

@end

NS_ASSUME_NONNULL_END

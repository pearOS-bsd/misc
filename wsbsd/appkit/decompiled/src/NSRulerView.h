/*
 * NSRulerView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSRulerView, the ruler an NSScrollView shows above/beside its document.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSRulerView_interface.txt.
 *
 * NSRulerView is an NSView (measured). This core reproduces the configuration +
 * marker model: initWithScrollView:orientation:, ruleThickness (17),
 * reservedThicknessForMarkers (15), reservedThicknessForAccessoryView (0),
 * originOffset (0), measurementUnits, clientView/accessoryView/scrollView, the
 * markers list (addMarker:/removeMarker:/setMarkers:), and requiredThickness =
 * ruleThickness + reservedThicknessForMarkers + reservedThicknessForAccessoryView
 * (measured). The hash-mark layout + drawing are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSRulerOrientation) {
    NSHorizontalRuler = 0,
    NSVerticalRuler = 1,
};

@class NSScrollView, NSRulerMarker;

@interface NSRulerView : NSView

- (instancetype)initWithScrollView:(nullable NSScrollView *)scrollView orientation:(NSRulerOrientation)orientation;

@property (nullable, weak) NSScrollView *scrollView;
@property NSRulerOrientation orientation;
@property CGFloat ruleThickness;
@property CGFloat reservedThicknessForMarkers;
@property CGFloat reservedThicknessForAccessoryView;
@property CGFloat originOffset;
@property (copy) NSString *measurementUnits;
@property (nullable, weak) NSView *clientView;
@property (nullable, strong) NSView *accessoryView;
@property (nullable, copy) NSArray<NSRulerMarker *> *markers;
@property (readonly) CGFloat requiredThickness;
@property (readonly) CGFloat baselineLocation;

- (void)addMarker:(NSRulerMarker *)marker;
- (void)removeMarker:(NSRulerMarker *)marker;

@end

NS_ASSUME_NONNULL_END

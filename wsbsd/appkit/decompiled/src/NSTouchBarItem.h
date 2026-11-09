/*
 * NSTouchBarItem.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTouchBarItem : NSObject <NSCoding> {
 *       @"NSString" _identifier;  f _visibilityPriority;  q _visibilityCount;
 *       B _requiresTrueCenterLayout;
 *   }
 *   @property (T@"NSString",R,C) identifier;  (Tf) visibilityPriority;
 *   @property (T@"NSView",R) view;  (T@"NSViewController",R) viewController;
 *   -initWithIdentifier: -customizationLabel -isVisible
 *
 * The abstract base of a touch-bar item: identifier and visibility priority.
 * The concrete view / viewController / customizationLabel come from subclasses
 * (NSCustomTouchBarItem, NSGroupTouchBarItem, …) and the live isVisible state
 * from the touch bar — both stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef float NSTouchBarItemPriority;
static const NSTouchBarItemPriority NSTouchBarItemPriorityHigh = 1000;
static const NSTouchBarItemPriority NSTouchBarItemPriorityNormal = 0;
static const NSTouchBarItemPriority NSTouchBarItemPriorityLow = -1000;

@class NSView, NSViewController;

@interface NSTouchBarItem : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier;

@property (readonly, copy) NSString *identifier;
@property NSTouchBarItemPriority visibilityPriority;
@property (nullable, readonly) NSView *view;
@property (nullable, readonly) NSViewController *viewController;
@property (nullable, readonly, copy) NSString *customizationLabel;
@property (readonly, getter=isVisible) BOOL visible;

@end

NS_ASSUME_NONNULL_END

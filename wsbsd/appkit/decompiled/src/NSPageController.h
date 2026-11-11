/*
 * NSPageController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPageController (: NSViewController), the page-based navigation controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPageController_interface.txt. Real ivars: _arrangedObjects,
 * _selectedIndex, _selectedViewController, _currentIdentifier, _transitionStyle,
 * _delegate, _snapshots, reuse/template caches, transition view + animator.
 *
 * Measured on this Mac: transitionStyle defaults to StackHistory(0), selectedIndex
 * 0, arrangedObjects empty; navigateForward:/navigateBack: step the selection by
 * ±1 clamped to the arrangedObjects bounds; setSelectedIndex: RAISES
 * NSInternalInconsistencyException ("index out of range") when out of bounds.
 *
 * This core reproduces the arrangedObjects/selectedIndex navigation model and
 * the value config. The delegate-driven view creation (selectedViewController,
 * currentIdentifier, snapshots, prepare/transition callbacks) and the live
 * swipe/transition animations are TODO(stage2).
 */

#import "NSViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class NSView;
@protocol NSPageControllerDelegate;

typedef NS_ENUM(NSInteger, NSPageControllerTransitionStyle) {
    NSPageControllerTransitionStyleStackHistory    = 0,
    NSPageControllerTransitionStyleStackBook        = 1,
    NSPageControllerTransitionStyleHorizontalStrip  = 2,
};

@interface NSPageController : NSViewController

@property (nullable, weak) id<NSPageControllerDelegate> delegate;
@property (copy) NSArray *arrangedObjects;
@property NSInteger selectedIndex;
@property (nullable, readonly, strong) NSViewController *selectedViewController;
@property (copy) NSString *currentIdentifier;
@property NSPageControllerTransitionStyle transitionStyle;

- (void)navigateForward:(nullable id)sender;
- (void)navigateBack:(nullable id)sender;
- (void)takeSelectedIndexFrom:(nullable id)sender;
- (void)navigateForwardToObject:(id)object;
- (void)removeForwardNavigableObjects;
- (void)completeTransition;

@end

@protocol NSPageControllerDelegate <NSObject>
@optional
- (NSString *)pageController:(NSPageController *)pageController identifierForObject:(id)object;
- (NSViewController *)pageController:(NSPageController *)pageController viewControllerForIdentifier:(NSString *)identifier;
- (void)pageController:(NSPageController *)pageController didTransitionToObject:(id)object;
- (void)pageControllerDidEndLiveTransition:(NSPageController *)pageController;
@end

NS_ASSUME_NONNULL_END

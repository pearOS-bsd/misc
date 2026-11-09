/*
 * NSViewController.h — 1:1 reimplementation (core). NSResponder subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSViewController : NSResponder <NSEditor, NSSeguePerforming, …> {
 *       @"NSString" _nibName;  @"NSBundle" _nibBundle;  @ _representedObject;
 *       @"NSString" _title;  @"NSView" _view;  @"NSArray" _topLevelObjects; …
 *   }
 *   -initWithNibName:bundle: -title -representedObject -view -isViewLoaded
 *   -childViewControllers -addChildViewController: -insertChildViewController:atIndex:
 *   -removeFromParentViewController -parentViewController -preferredContentSize
 *
 * Manages a view and a tree of child controllers. view is lazily created by
 * loadView (default: an empty NSView). Child management keeps parentViewController
 * in sync. Nib loading, the appearance lifecycle (viewDidLoad/viewWillAppear),
 * KVB editor registration and segues are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSResponder.h"

NS_ASSUME_NONNULL_BEGIN

@class NSView;

@interface NSViewController : NSResponder

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil;

@property (nullable, copy) NSString *title;
@property (nullable, strong) id representedObject;
@property (strong) NSView *view;
@property (readonly) BOOL isViewLoaded;
@property CGSize preferredContentSize;

- (void)loadView;

@property (readonly, copy) NSArray<NSViewController *> *childViewControllers;
@property (nullable, readonly, weak) NSViewController *parentViewController;
- (void)addChildViewController:(NSViewController *)childViewController;
- (void)insertChildViewController:(NSViewController *)childViewController atIndex:(NSInteger)index;
- (void)removeFromParentViewController;

@end

NS_ASSUME_NONNULL_END

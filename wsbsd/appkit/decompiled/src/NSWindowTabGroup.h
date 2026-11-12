/*
 * NSWindowTabGroup.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSWindowTabGroup (a window's -tabGroup).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSWindowTabGroup_interface.txt. Real ivars: _identifier,
 * _allowsDraggingTabs, _allowsDetachingTabs.
 *
 * This core reproduces the window-list + selection model: identifier,
 * windows (managed by addWindow:/insertWindow:atIndex:/removeWindow:, SPI),
 * selectedWindow (weak, first added auto-selects; removing the selected picks a
 * neighbour), tabBarEnabled/shouldShowTabBarWithOneItem/overviewVisible config,
 * tabBarVisible derived. allowsDraggingTabs/allowsDetachingTabs default YES
 * (NSWindow tabbing default; not measurable on a standalone group). The tab-bar
 * UI, overview animation, plusTab and window-server tabbing are TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSWindow;

@interface NSWindowTabGroup : NSObject

- (instancetype)initWithTabbingIdentifier:(NSString *)identifier;

@property (copy) NSString *identifier;
@property (readonly, copy) NSArray<NSWindow *> *windows;
@property (nullable, weak) NSWindow *selectedWindow;
@property (getter=isTabBarEnabled) BOOL tabBarEnabled;
@property BOOL shouldShowTabBarWithOneItem;
@property (readonly, getter=isTabBarVisible) BOOL tabBarVisible;
@property (getter=isOverviewVisible) BOOL overviewVisible;
@property BOOL allowsDraggingTabs;       /* default YES */
@property BOOL allowsDetachingTabs;      /* default YES */

- (void)addWindow:(NSWindow *)window;
- (void)insertWindow:(NSWindow *)window atIndex:(NSInteger)index;
- (void)removeWindow:(NSWindow *)window;

@end

NS_ASSUME_NONNULL_END

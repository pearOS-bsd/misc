/*
 * NSWindowTabGroup.m — behavioral-1:1 window-list + selection core. See header.
 */

#import "NSWindowTabGroup.h"

@implementation NSWindowTabGroup {
    NSString *_identifier;
    NSMutableArray<NSWindow *> *_windows;
    __weak NSWindow *_selectedWindow;
    BOOL _tabBarEnabled;
    BOOL _shouldShowTabBarWithOneItem;
    BOOL _overviewVisible;
    BOOL _allowsDraggingTabs;
    BOOL _allowsDetachingTabs;
}

- (instancetype)initWithTabbingIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy] ?: @"";
        _windows = [NSMutableArray array];
        _tabBarEnabled = YES;
        _allowsDraggingTabs = YES;   /* default per NSWindow tabbing docs */
        _allowsDetachingTabs = YES;
    }
    return self;
}

- (instancetype)init { return [self initWithTabbingIdentifier:@""]; }

- (NSString *)identifier { return _identifier; }
- (void)setIdentifier:(NSString *)s { _identifier = [s copy] ?: @""; }
- (NSArray<NSWindow *> *)windows { return [_windows copy]; }
- (NSWindow *)selectedWindow { return _selectedWindow; }
- (void)setSelectedWindow:(NSWindow *)w { if (!w || [_windows containsObject:w]) _selectedWindow = w; }
- (BOOL)isTabBarEnabled { return _tabBarEnabled; }
- (void)setTabBarEnabled:(BOOL)v { _tabBarEnabled = v; }
- (BOOL)shouldShowTabBarWithOneItem { return _shouldShowTabBarWithOneItem; }
- (void)setShouldShowTabBarWithOneItem:(BOOL)v { _shouldShowTabBarWithOneItem = v; }
- (BOOL)isOverviewVisible { return _overviewVisible; }
- (void)setOverviewVisible:(BOOL)v { _overviewVisible = v; }
- (BOOL)allowsDraggingTabs { return _allowsDraggingTabs; }
- (void)setAllowsDraggingTabs:(BOOL)v { _allowsDraggingTabs = v; }
- (BOOL)allowsDetachingTabs { return _allowsDetachingTabs; }
- (void)setAllowsDetachingTabs:(BOOL)v { _allowsDetachingTabs = v; }

- (BOOL)isTabBarVisible
{
    return _tabBarEnabled && (_windows.count > 1 || (_windows.count == 1 && _shouldShowTabBarWithOneItem));
}

- (void)addWindow:(NSWindow *)window { [self insertWindow:window atIndex:(NSInteger)_windows.count]; }

- (void)insertWindow:(NSWindow *)window atIndex:(NSInteger)index
{
    if (!window || [_windows containsObject:window]) return;
    if (index < 0) index = 0;
    if (index > (NSInteger)_windows.count) index = (NSInteger)_windows.count;
    [_windows insertObject:window atIndex:index];
    if (!_selectedWindow) _selectedWindow = window;   /* first window becomes selected */
}

- (void)removeWindow:(NSWindow *)window
{
    NSUInteger i = [_windows indexOfObject:window];
    if (i == NSNotFound) return;
    [_windows removeObjectAtIndex:i];
    if (_selectedWindow == window) {
        if (_windows.count == 0) _selectedWindow = nil;
        else _selectedWindow = _windows[MIN(i, _windows.count - 1)];  /* neighbour */
    }
}

@end

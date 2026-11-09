/*
 * NSViewController.m — 1:1 (core). See NSViewController.h for interface evidence.
 *
 * The view is created lazily: -view calls -loadView the first time (and
 * isViewLoaded tracks it). The default -loadView installs an empty NSView.
 * Child management mirrors AppKit: addChildViewController: appends (removing the
 * child from any previous parent first) and sets parentViewController;
 * removeFromParentViewController detaches. Nib loading and the appearance
 * lifecycle are stage2.
 */
#import "NSViewController.h"
#import "NSView.h"

@interface NSViewController ()
@property (nullable, weak, readwrite) NSViewController *parentViewController;
@end

@implementation NSViewController {
    NSString *_nibName;
    NSBundle *_nibBundle;
    NSString *_title;
    id _representedObject;
    NSView *_view;
    BOOL _viewLoaded;
    CGSize _preferredContentSize;
    NSMutableArray<NSViewController *> *_children;
}
@synthesize parentViewController = _parentViewController;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super init];
    if (self) {
        _nibName = [nibNameOrNil copy];
        _nibBundle = nibBundleOrNil;
        _children = [NSMutableArray array];
    }
    return self;
}

- (instancetype)init { return [self initWithNibName:nil bundle:nil]; }

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)v { _title = [v copy]; }
- (id)representedObject { return _representedObject; }
- (void)setRepresentedObject:(id)v { _representedObject = v; }
- (CGSize)preferredContentSize { return _preferredContentSize; }
- (void)setPreferredContentSize:(CGSize)v { _preferredContentSize = v; }

- (BOOL)isViewLoaded { return _viewLoaded; }

- (void)loadView
{
    /* default: an empty view (AppKit loads from the nib when one is set). */
    _view = [[NSView alloc] initWithFrame:CGRectZero];
}

- (NSView *)view
{
    if (!_viewLoaded && !_view) {
        [self loadView];
        _viewLoaded = YES;
    }
    return _view;
}

- (void)setView:(NSView *)v { _view = v; _viewLoaded = (v != nil); }

- (NSArray<NSViewController *> *)childViewControllers { return [_children copy]; }

- (void)insertChildViewController:(NSViewController *)child atIndex:(NSInteger)index
{
    if (!child) return;
    if (child.parentViewController) [child removeFromParentViewController];
    if (index < 0 || index > (NSInteger)_children.count) index = _children.count;
    [_children insertObject:child atIndex:index];
    child.parentViewController = self;
}

- (void)addChildViewController:(NSViewController *)child
{
    [self insertChildViewController:child atIndex:_children.count];
}

- (void)removeFromParentViewController
{
    NSViewController *parent = self.parentViewController;
    if (!parent) return;
    [parent->_children removeObjectIdenticalTo:self];
    self.parentViewController = nil;
}

@end

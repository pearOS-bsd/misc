/*
 * NSPageController.m — behavioral-1:1 page-model core.
 * See NSPageController.h (delegate-driven views + transitions are stage2).
 */

#import "NSPageController.h"

@implementation NSPageController {
    NSMutableArray *_arrangedObjects;
    NSInteger _selectedIndex;
    NSString *_currentIdentifier;
    NSPageControllerTransitionStyle _transitionStyle;
    __weak id<NSPageControllerDelegate> _delegate;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nibName bundle:bundle];
    if (self) {
        _arrangedObjects = [NSMutableArray array];
        _selectedIndex = 0;
        _transitionStyle = NSPageControllerTransitionStyleStackHistory;
    }
    return self;
}

- (instancetype)init { return [self initWithNibName:nil bundle:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

- (id<NSPageControllerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSPageControllerDelegate>)d { _delegate = d; }

- (NSPageControllerTransitionStyle)transitionStyle { return _transitionStyle; }
- (void)setTransitionStyle:(NSPageControllerTransitionStyle)s { _transitionStyle = s; }

- (NSArray *)arrangedObjects { return [_arrangedObjects copy]; }
- (void)setArrangedObjects:(NSArray *)objects
{
    _arrangedObjects = [objects mutableCopy] ?: [NSMutableArray array];
    if (_arrangedObjects.count == 0) _selectedIndex = 0;
    else if (_selectedIndex >= (NSInteger)_arrangedObjects.count) _selectedIndex = _arrangedObjects.count - 1;
}

- (NSInteger)selectedIndex { return _selectedIndex; }
- (void)setSelectedIndex:(NSInteger)index
{
    NSInteger n = (NSInteger)_arrangedObjects.count;
    BOOL ok = (n == 0) ? (index == 0) : (index >= 0 && index < n);
    if (!ok) [NSException raise:NSInternalInconsistencyException format:@"index out of range"];
    _selectedIndex = index;
    /* TODO(stage2): drive selectedViewController + transition to the object. */
}

- (NSViewController *)selectedViewController { return nil; /* stage2: delegate-provided */ }
- (NSString *)currentIdentifier { return _currentIdentifier; }
- (void)setCurrentIdentifier:(NSString *)identifier { _currentIdentifier = [identifier copy]; }

/* --- navigation (clamped, no raise) --- */

- (void)navigateForward:(id)sender
{
    if (_arrangedObjects.count == 0) return;
    if (_selectedIndex + 1 < (NSInteger)_arrangedObjects.count) _selectedIndex++;
}

- (void)navigateBack:(id)sender
{
    if (_selectedIndex > 0) _selectedIndex--;
}

- (void)takeSelectedIndexFrom:(id)sender
{
    if ([sender respondsToSelector:@selector(integerValue)])
        [self setSelectedIndex:[sender integerValue]];
}

- (void)navigateForwardToObject:(id)object
{
    if (!object) return;
    [_arrangedObjects addObject:object];
    _selectedIndex = _arrangedObjects.count - 1;
}

- (void)removeForwardNavigableObjects
{
    NSInteger keep = _selectedIndex + 1;
    if (keep < (NSInteger)_arrangedObjects.count)
        [_arrangedObjects removeObjectsInRange:NSMakeRange(keep, _arrangedObjects.count - keep)];
}

- (void)completeTransition { /* TODO(stage2): finish the live transition animation. */ }

@end

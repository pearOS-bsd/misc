/*
 * NSTitlebarAccessoryViewController.m — 1:1 (core). See the header for evidence.
 *
 * Tracks layoutAttribute (default Bottom, _layoutAttribute), the hidden flag
 * (_hidden), fullScreenMinHeight and automaticallyAdjustsSize (default YES).
 * Installing the view into the window titlebar, the reveal animation driven by
 * scroll and the separator view are stage2.
 */
#import "NSTitlebarAccessoryViewController.h"

@implementation NSTitlebarAccessoryViewController {
    NSLayoutAttribute _layoutAttribute;
    CGFloat _fullScreenMinHeight;
    BOOL _hidden;                      /* _hidden bitfield */
    BOOL _automaticallyAdjustsSize;
}

- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nib bundle:bundle];
    if (self) {
        _layoutAttribute = NSLayoutAttributeBottom;
        _automaticallyAdjustsSize = YES;
    }
    return self;
}

- (NSLayoutAttribute)layoutAttribute { return _layoutAttribute; }
- (void)setLayoutAttribute:(NSLayoutAttribute)v { _layoutAttribute = v; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)v { _hidden = v; }
- (CGFloat)fullScreenMinHeight { return _fullScreenMinHeight; }
- (void)setFullScreenMinHeight:(CGFloat)v { _fullScreenMinHeight = v; }
- (BOOL)automaticallyAdjustsSize { return _automaticallyAdjustsSize; }
- (void)setAutomaticallyAdjustsSize:(BOOL)v { _automaticallyAdjustsSize = v; }

@end

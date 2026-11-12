/*
 * NSPrintPanel.m — behavioral-1:1 core. See the header.
 */

#import "NSPrintPanel.h"

@implementation NSPrintPanel {
    NSMutableArray *_accessoryControllers;
    NSPrintPanelOptions _options;
    NSString *_defaultButtonTitle;
    NSString *_helpAnchor;
    NSString *_jobStyleHint;
}

+ (instancetype)printPanel { return [[self alloc] init]; }

- (instancetype)init
{
    self = [super init];
    if (self) {
        _accessoryControllers = [NSMutableArray array];
        _options = NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange;   /* measured (3) */
    }
    return self;
}

- (void)addAccessoryController:(id)accessoryController
{
    if (accessoryController && ![_accessoryControllers containsObject:accessoryController])
        [_accessoryControllers addObject:accessoryController];
}
- (void)removeAccessoryController:(id)accessoryController { [_accessoryControllers removeObject:accessoryController]; }
- (NSArray *)accessoryControllers { return [_accessoryControllers copy]; }

- (NSPrintPanelOptions)options { return _options; }
- (void)setOptions:(NSPrintPanelOptions)o { _options = o; }
- (NSString *)defaultButtonTitle { return _defaultButtonTitle; }
- (void)setDefaultButtonTitle:(NSString *)s { _defaultButtonTitle = [s copy]; }
- (NSString *)helpAnchor { return _helpAnchor; }
- (void)setHelpAnchor:(NSString *)s { _helpAnchor = [s copy]; }
- (NSString *)jobStyleHint { return _jobStyleHint; }
- (void)setJobStyleHint:(NSString *)s { _jobStyleHint = [s copy]; }

- (NSPrintInfo *)printInfo { return nil; }   /* set during a run = stage2 */

@end

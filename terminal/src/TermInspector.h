#import <AppKit/AppKit.h>
#import "TermView.h"
/* The Inspector (Shell > Show Inspector): the profile, the title, the size of the window and the processes running on the terminal's tty, refreshed twice a second. */
@interface TermInspector : NSObject
+ (void)showForTerm:(TermView *)t;
+ (void)setCurrentTerm:(TermView *)t;      /* the inspector follows the front terminal */
@end

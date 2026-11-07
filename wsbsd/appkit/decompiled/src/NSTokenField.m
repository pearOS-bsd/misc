/* NSTokenField.m — 1:1 (core). Delegates to NSTokenFieldCell. */
#import "NSTokenField.h"

@implementation NSTokenField

+ (Class)cellClass { return [NSTokenFieldCell class]; }
- (NSTokenFieldCell *)tkCell { return (NSTokenFieldCell *)self.cell; }

- (NSTokenStyle)tokenStyle { return [self.tkCell tokenStyle]; }
- (void)setTokenStyle:(NSTokenStyle)s { [self.tkCell setTokenStyle:s]; }
- (NSTimeInterval)completionDelay { return [self.tkCell completionDelay]; }
- (void)setCompletionDelay:(NSTimeInterval)d { [self.tkCell setCompletionDelay:d]; }
- (NSCharacterSet *)tokenizingCharacterSet { return [self.tkCell tokenizingCharacterSet]; }
- (void)setTokenizingCharacterSet:(NSCharacterSet *)s { [self.tkCell setTokenizingCharacterSet:s]; }

@end

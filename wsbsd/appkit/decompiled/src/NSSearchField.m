/* NSSearchField.m — 1:1 (core). Delegates to NSSearchFieldCell. */
#import "NSSearchField.h"

@implementation NSSearchField

+ (Class)cellClass { return [NSSearchFieldCell class]; }
- (NSSearchFieldCell *)sfCell { return (NSSearchFieldCell *)self.cell; }

- (NSInteger)maximumRecents { return [self.sfCell maximumRecents]; }
- (void)setMaximumRecents:(NSInteger)m { [self.sfCell setMaximumRecents:m]; }
- (BOOL)sendsWholeSearchString { return [self.sfCell sendsWholeSearchString]; }
- (void)setSendsWholeSearchString:(BOOL)v { [self.sfCell setSendsWholeSearchString:v]; }
- (NSArray<NSString *> *)recentSearches { return [self.sfCell recentSearches]; }
- (void)setRecentSearches:(NSArray<NSString *> *)r { [self.sfCell setRecentSearches:r]; }

@end

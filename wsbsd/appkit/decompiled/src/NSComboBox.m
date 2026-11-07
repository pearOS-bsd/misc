/* NSComboBox.m — 1:1 (core). Delegates to NSComboBoxCell. */
#import "NSComboBox.h"

@implementation NSComboBox

+ (Class)cellClass { return [NSComboBoxCell class]; }
- (NSComboBoxCell *)cbCell { return (NSComboBoxCell *)self.cell; }

- (NSInteger)numberOfVisibleItems { return [self.cbCell numberOfVisibleItems]; }
- (void)setNumberOfVisibleItems:(NSInteger)n { [self.cbCell setNumberOfVisibleItems:n]; }
- (BOOL)usesDataSource { return [self.cbCell usesDataSource]; }
- (void)setUsesDataSource:(BOOL)v { [self.cbCell setUsesDataSource:v]; }
- (BOOL)hasVerticalScroller { return [self.cbCell hasVerticalScroller]; }
- (void)setHasVerticalScroller:(BOOL)v { [self.cbCell setHasVerticalScroller:v]; }
- (NSInteger)numberOfItems { return [self.cbCell numberOfItems]; }
- (void)addItemWithObjectValue:(id)object { [self.cbCell addItemWithObjectValue:object]; }
- (id)itemObjectValueAtIndex:(NSInteger)index { return [self.cbCell itemObjectValueAtIndex:index]; }

@end

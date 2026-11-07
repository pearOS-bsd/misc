/* NSPopUpButton.m — 1:1 (core). Delegates to NSPopUpButtonCell.
 * Evidence ../evidence/popup (indexOfSelectedItem 0x1850e667c -> cell). */
#import "NSPopUpButton.h"

@implementation NSPopUpButton

+ (Class)cellClass { return [NSPopUpButtonCell class]; }
- (NSPopUpButtonCell *)pcell { return (NSPopUpButtonCell *)self.cell; }

- (BOOL)pullsDown { return [self.pcell pullsDown]; }
- (void)setPullsDown:(BOOL)v { [self.pcell setPullsDown:v]; }
- (NSInteger)numberOfItems { return [self.pcell numberOfItems]; }
- (NSInteger)indexOfSelectedItem { return [self.pcell indexOfSelectedItem]; }
- (NSMenuItem *)selectedItem { return [self.pcell selectedItem]; }
- (void)addItemWithTitle:(NSString *)title { [self.pcell addItemWithTitle:title]; }
- (void)selectItemAtIndex:(NSInteger)index { [self.pcell selectItemAtIndex:index]; }
- (NSString *)titleOfSelectedItem { return [self.pcell titleOfSelectedItem]; }

@end

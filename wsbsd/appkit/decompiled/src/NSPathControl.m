/* NSPathControl.m — 1:1 (core). Delegates to NSPathCell. */
#import "NSPathControl.h"

@implementation NSPathControl

+ (Class)cellClass { return [NSPathCell class]; }
- (NSPathCell *)pathCell { return (NSPathCell *)self.cell; }

- (NSPathStyle)pathStyle { return [self.pathCell pathStyle]; }
- (void)setPathStyle:(NSPathStyle)s { [self.pathCell setPathStyle:s]; }
- (NSURL *)URL { return [self.pathCell URL]; }
- (void)setURL:(NSURL *)u { [self.pathCell setURL:u]; }
- (BOOL)isEditable { return [self.pathCell isEditable]; }
- (void)setEditable:(BOOL)e { [self.pathCell setEditable:e]; }

@end

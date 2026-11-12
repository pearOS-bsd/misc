/*
 * NSSecureTextFieldCell.m — behavioral-1:1 core. See the header.
 */

#import "NSSecureTextFieldCell.h"

@implementation NSSecureTextFieldCell {
    BOOL _echosBullets;
}

- (instancetype)initTextCell:(NSString *)string
{
    self = [super init];
    if (self) {
        self.stringValue = string;
        _echosBullets = YES;   /* measured */
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) _echosBullets = YES;
    return self;
}

- (BOOL)echosBullets { return _echosBullets; }
- (void)setEchosBullets:(BOOL)v { _echosBullets = v; }

@end

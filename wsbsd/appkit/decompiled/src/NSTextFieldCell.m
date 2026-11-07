/*
 * NSTextFieldCell.m — 1:1 reimplementation of AppKit's NSTextFieldCell (core).
 * Evidence under ../evidence/textfield. backgroundColor (_backgroundColor
 * @0xf2c) and the _tfFlags (@0xf28) drawsBackground/placeholder bits are stage2.
 */
#import "NSTextFieldCell.h"

@implementation NSTextFieldCell {
    NSString *_stringValue;   /* shipping: NSCell _contents via formatter (stage2) */
}

- (NSString *)stringValue { return _stringValue ?: @""; }
- (void)setStringValue:(NSString *)stringValue { _stringValue = [stringValue copy]; }

@end

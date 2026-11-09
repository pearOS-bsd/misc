/*
 * NSPathControlItem.m — 1:1 (core). See NSPathControlItem.h for the evidence.
 *
 * title and attributedTitle are kept in sync: setting the plain title replaces
 * the attributed title with a plain run, and setting the attributed title
 * updates the plain title to its string value — matching how AppKit routes both
 * through the component cell's string value. image and URL are stored directly.
 * The NSPathComponentCell backing and drawing are stage2.
 */
#import "NSPathControlItem.h"

@implementation NSPathControlItem {
    NSString *_title;
    NSAttributedString *_attributedTitle;
    id _image;
    NSURL *_URL;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _title = @""; _attributedTitle = [[NSAttributedString alloc] initWithString:@""]; }
    return self;
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title
{
    _title = [title copy] ?: @"";
    _attributedTitle = [[NSAttributedString alloc] initWithString:_title];
}

- (NSAttributedString *)attributedTitle { return _attributedTitle; }
- (void)setAttributedTitle:(NSAttributedString *)attributedTitle
{
    _attributedTitle = [attributedTitle copy] ?: [[NSAttributedString alloc] initWithString:@""];
    _title = [_attributedTitle.string copy];
}

- (id)image { return _image; }
- (void)setImage:(id)image { _image = image; }
- (NSURL *)URL { return _URL; }
- (void)setURL:(NSURL *)URL { _URL = [URL copy]; }

@end

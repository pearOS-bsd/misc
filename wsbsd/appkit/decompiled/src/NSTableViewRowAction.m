/*
 * NSTableViewRowAction.m — 1:1 (core). See the header for the interface evidence.
 *
 * Stores style, title, the handler block, background colour, image and
 * allowsFullSwipe (which defaults YES, as AppKit allows a full swipe to trigger
 * the first action). The swipe presentation and the style-derived default
 * background colour (system red for Destructive) are stage2.
 */
#import "NSTableViewRowAction.h"

@implementation NSTableViewRowAction {
    NSTableViewRowActionStyle _style;
    NSString *_title;
    NSTableViewRowActionHandler _handler;
    id _backgroundColor;
    id _image;
    BOOL _allowsFullSwipe;
}

+ (instancetype)rowActionWithStyle:(NSTableViewRowActionStyle)style
                             title:(NSString *)title
                           handler:(NSTableViewRowActionHandler)handler
{
    NSTableViewRowAction *a = [[self alloc] init];
    a->_style = style;
    a->_title = [title copy];
    a->_handler = [handler copy];
    a->_allowsFullSwipe = YES;
    return a;
}

- (NSTableViewRowActionStyle)style { return _style; }
- (void)setStyle:(NSTableViewRowActionStyle)v { _style = v; }
- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)v { _title = [v copy]; }
- (NSTableViewRowActionHandler)handler { return _handler; }
- (id)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(id)v { _backgroundColor = v; }
- (id)image { return _image; }
- (void)setImage:(id)v { _image = v; }
- (BOOL)allowsFullSwipe { return _allowsFullSwipe; }
- (void)setAllowsFullSwipe:(BOOL)v { _allowsFullSwipe = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSTableViewRowAction *c = [NSTableViewRowAction rowActionWithStyle:_style title:_title handler:_handler];
    c->_backgroundColor = _backgroundColor; c->_image = _image; c->_allowsFullSwipe = _allowsFullSwipe;
    return c;
}

@end

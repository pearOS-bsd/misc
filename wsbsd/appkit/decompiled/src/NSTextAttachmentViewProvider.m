/*
 * NSTextAttachmentViewProvider.m — behavioral-1:1 core. See the header.
 */

#import "NSTextAttachmentViewProvider.h"

@implementation NSTextAttachmentViewProvider {
    NSView *_view;
    BOOL _tracksTextAttachmentViewBounds;
    __weak NSTextAttachment *_textAttachment;
    __weak NSTextLayoutManager *_textLayoutManager;
    id<NSTextLocation> _location;
    __weak NSView *_parentView;
}

- (instancetype)initWithTextAttachment:(NSTextAttachment *)textAttachment
                            parentView:(NSView *)parentView
                     textLayoutManager:(NSTextLayoutManager *)textLayoutManager
                              location:(id<NSTextLocation>)location
{
    self = [super init];
    if (self) {
        _textAttachment = textAttachment;
        _parentView = parentView;
        _textLayoutManager = textLayoutManager;
        _location = location;
        /* tracks=NO, view=nil (measured) */
    }
    return self;
}

- (NSTextAttachment *)textAttachment { return _textAttachment; }
- (NSTextLayoutManager *)textLayoutManager { return _textLayoutManager; }
- (id<NSTextLocation>)location { return _location; }
- (void)setLocation:(id<NSTextLocation>)l { _location = l; }
- (NSView *)view { return _view; }
- (void)setView:(NSView *)v { _view = v; }
- (BOOL)tracksTextAttachmentViewBounds { return _tracksTextAttachmentViewBounds; }
- (void)setTracksTextAttachmentViewBounds:(BOOL)v { _tracksTextAttachmentViewBounds = v; }

- (void)loadView
{
    /* Override point: a subclass creates and assigns self.view here.
       The base implementation does nothing, so -view stays nil (measured). */
}

- (CGRect)attachmentBoundsForAttributes:(NSDictionary *)attributes
                               location:(id<NSTextLocation>)location
                          textContainer:(NSTextContainer *)textContainer
                   proposedLineFragment:(CGRect)proposedLineFragment
                               position:(CGPoint)position
{
    /* base returns an empty rect; a subclass sizes it from its view (stage2). */
    return CGRectZero;
}

@end

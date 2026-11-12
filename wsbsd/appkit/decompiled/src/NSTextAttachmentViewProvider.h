/*
 * NSTextAttachmentViewProvider.h — 1:1 reimplementation (behavioral core) of
 * AppKit/TextKit 2's NSTextAttachmentViewProvider, which vends the NSView that
 * renders a view-based text attachment.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSTextAttachmentViewProvider_interface.txt. Real ivars: _view,
 * _tracksTextAttachmentViewBounds, _textAttachment (weak), _textLayoutManager
 * (weak), _location, _characterIndex, _layoutManager (weak).
 *
 * This core reproduces construction (initWithTextAttachment:parentView:
 * textLayoutManager:location: stores the attachment + location), the stored
 * accessors, and the subclass override points -loadView (base no-op, leaving
 * view nil — measured) and -attachmentBounds… (base returns CGRectZero). The
 * actual view instantiation/layout is the subclass's job (stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSTextRange.h"   /* for id<NSTextLocation> */

NS_ASSUME_NONNULL_BEGIN

@class NSTextAttachment, NSView, NSTextLayoutManager, NSTextContainer;

@interface NSTextAttachmentViewProvider : NSObject

- (instancetype)initWithTextAttachment:(nullable NSTextAttachment *)textAttachment
                            parentView:(nullable NSView *)parentView
                     textLayoutManager:(nullable NSTextLayoutManager *)textLayoutManager
                              location:(nullable id<NSTextLocation>)location;

@property (readonly, weak, nullable) NSTextAttachment *textAttachment;
@property (readonly, weak, nullable) NSTextLayoutManager *textLayoutManager;
@property (nullable, strong) id<NSTextLocation> location;
@property (nullable, strong) NSView *view;
@property BOOL tracksTextAttachmentViewBounds;

- (void)loadView;
- (CGRect)attachmentBoundsForAttributes:(NSDictionary *)attributes
                               location:(id<NSTextLocation>)location
                          textContainer:(nullable NSTextContainer *)textContainer
                   proposedLineFragment:(CGRect)proposedLineFragment
                               position:(CGPoint)position;

@end

NS_ASSUME_NONNULL_END

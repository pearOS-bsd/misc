/*
 * NSClipView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/scroll: _docView at ivar 0x3e8. Holds the document view
 * that NSScrollView scrolls. (setDocumentView: also rewires notifications and
 * frame observation — stage2.)
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSClipView : NSView
@property (nullable, strong) NSView *documentView;
@end

NS_ASSUME_NONNULL_END

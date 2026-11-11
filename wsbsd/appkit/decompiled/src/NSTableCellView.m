/*
 * NSTableCellView.m — behavioral-1:1 core. See NSTableCellView.h.
 */

#import "NSTableCellView.h"
#import "NSDraggingImageComponent.h"

@implementation NSTableCellView {
    id _objectValue;
    NSTextField *_textField;
    NSImageView *_imageView;
    NSBackgroundStyle _backgroundStyle;
    NSTableViewRowSizeStyle _rowSizeStyle;
    NSTintConfiguration *_tintConfiguration;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _backgroundStyle = NSBackgroundStyleNormal;   /* measured */
        _rowSizeStyle = NSTableViewRowSizeStyleCustom; /* measured: Custom(0) */
    }
    return self;
}

- (id)objectValue { return _objectValue; }
- (void)setObjectValue:(id)v { _objectValue = v; }

- (NSTextField *)textField { return _textField; }
- (void)setTextField:(NSTextField *)tf { _textField = tf; }

- (NSImageView *)imageView { return _imageView; }
- (void)setImageView:(NSImageView *)iv { _imageView = iv; }

- (NSBackgroundStyle)backgroundStyle { return _backgroundStyle; }
- (void)setBackgroundStyle:(NSBackgroundStyle)s
{
    _backgroundStyle = s;
    /* TODO(stage2): propagate to textField.cell / imageView.cell backgroundStyle. */
}

- (NSTableViewRowSizeStyle)rowSizeStyle { return _rowSizeStyle; }
- (void)setRowSizeStyle:(NSTableViewRowSizeStyle)s { _rowSizeStyle = s; }

- (NSTintConfiguration *)tintConfiguration { return _tintConfiguration; }
- (void)setTintConfiguration:(NSTintConfiguration *)c { _tintConfiguration = c; }

- (NSArray<NSDraggingImageComponent *> *)draggingImageComponents
{
    /* One component per populated outlet; with neither, a single view-snapshot
     * component (measured count==1). TODO(stage2): real rendered contents/frame. */
    NSMutableArray *comps = [NSMutableArray array];
    if (_imageView)
        [comps addObject:[NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey]];
    if (_textField)
        [comps addObject:[NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey]];
    if (comps.count == 0)
        [comps addObject:[NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey]];
    return comps;
}

@end

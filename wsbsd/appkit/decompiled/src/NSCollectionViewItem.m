/*
 * NSCollectionViewItem.m — 1:1 (core). See NSCollectionViewItem.h for evidence.
 *
 * Inherits NSViewController (view/representedObject). selected and highlightState
 * are the _cviFlags bits b0 and b3-4; collectionView is a weak back-link and
 * imageView/textField are weak outlets. The item view normally reflects
 * selection/highlight when drawing — that drawing, plus dragging components and
 * reuse bookkeeping, is stage2.
 */
#import "NSCollectionViewItem.h"

@implementation NSCollectionViewItem {
    BOOL _selected;                                 /* _cviFlags b0 */
    NSCollectionViewItemHighlightState _highlight;  /* _cviFlags b3-4 */
    __weak id _collectionView;
    __weak id _imageView;
    __weak id _textField;
}

- (BOOL)isSelected { return _selected; }
- (void)setSelected:(BOOL)v { _selected = v; }
- (NSCollectionViewItemHighlightState)highlightState { return _highlight; }
- (void)setHighlightState:(NSCollectionViewItemHighlightState)v { _highlight = v; }
- (id)collectionView { return _collectionView; }
- (void)setCollectionView:(id)v { _collectionView = v; }
- (id)imageView { return _imageView; }
- (void)setImageView:(id)v { _imageView = v; }
- (id)textField { return _textField; }
- (void)setTextField:(id)v { _textField = v; }

@end

/*
 * NSCollectionView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionView.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCollectionView_interface.txt.
 *
 * NSCollectionView is an NSView (measured). This core reproduces the
 * configuration + data-source counting model: dataSource/delegate (weak),
 * collectionViewLayout, selectable (NO) / allowsMultipleSelection (NO) /
 * allowsEmptySelection (YES), backgroundColors, selectionIndexPaths,
 * numberOfSections (the data source's count, else 1 — measured) and
 * numberOfItemsInSection:. Item-view registration/dequeue, layout and drawing
 * are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@class NSCollectionView, NSCollectionViewLayout, NSColor;

@protocol NSCollectionViewDataSource <NSObject>
@required
- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
@optional
- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView;
@end

@interface NSCollectionView : NSView

@property (nullable, weak) id<NSCollectionViewDataSource> dataSource;
@property (nullable, weak) id delegate;
@property (nullable, strong) NSCollectionViewLayout *collectionViewLayout;

@property (getter=isSelectable) BOOL selectable;
@property BOOL allowsMultipleSelection;
@property BOOL allowsEmptySelection;
@property (copy) NSArray<NSColor *> *backgroundColors;
@property (copy) NSSet<NSIndexPath *> *selectionIndexPaths;

@property (readonly) NSInteger numberOfSections;
- (NSInteger)numberOfItemsInSection:(NSInteger)section;
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END

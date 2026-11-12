/*
 * NSTextContentManager.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextContentManager, the abstract owner of a document's text
 * elements that drives one or more NSTextLayoutManagers.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextContentManager_interface.txt.
 * Adopts NSTextElementProvider.
 *
 * This core reproduces the manager-list + transaction model: delegate,
 * textLayoutManagers with addTextLayoutManager:/removeTextLayoutManager:,
 * primaryTextLayoutManager (independent, nil until set — measured),
 * hasEditingTransaction toggled across performEditingTransactionUsingBlock:,
 * automaticallySynchronizesTextLayoutManagers (YES) /
 * automaticallySynchronizesToBackingStore (NO). The content storage itself —
 * documentRange, textElementsForRange:, enumeration, replaceContentsInRange: —
 * is the subclass's responsibility (TODO(stage2); the base returns empty/nil).
 */

#import <Foundation/Foundation.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextLayoutManager, NSTextElement, NSTextContentManager;

@protocol NSTextContentManagerDelegate <NSObject>
@optional
- (nullable NSTextElement *)textContentManager:(NSTextContentManager *)textContentManager textElementAtLocation:(id<NSTextLocation>)location;
- (BOOL)textContentManager:(NSTextContentManager *)textContentManager shouldEnumerateTextElement:(NSTextElement *)textElement options:(NSInteger)options;
@end

@interface NSTextContentManager : NSObject

@property (nullable, weak) id<NSTextContentManagerDelegate> delegate;
@property (readonly, copy) NSArray<NSTextLayoutManager *> *textLayoutManagers;
@property (nullable, strong) NSTextLayoutManager *primaryTextLayoutManager;
@property (readonly) BOOL hasEditingTransaction;
@property BOOL automaticallySynchronizesTextLayoutManagers;
@property BOOL automaticallySynchronizesToBackingStore;
@property (readonly, nullable) NSTextRange *documentRange;

- (void)addTextLayoutManager:(NSTextLayoutManager *)textLayoutManager;
- (void)removeTextLayoutManager:(NSTextLayoutManager *)textLayoutManager;

- (void)performEditingTransactionUsingBlock:(void (NS_NOESCAPE ^)(void))transaction;

/* subclass content hooks (base = empty / nil) */
- (nullable NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range;

@end

NS_ASSUME_NONNULL_END

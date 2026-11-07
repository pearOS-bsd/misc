/*
 * NSSearchFieldCell.h — 1:1 reimplementation (core). NSTextFieldCell subclass.
 * Evidence ../evidence/search: _sfFlags @0xe68 — sendsWholeSearchString = bit 0,
 * maximumRecents = bits 1-8 (0xff means "default", reported as -1); clamp 0..254.
 * recentSearches is a separate array.
 */
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSearchFieldCell : NSTextFieldCell
@property NSInteger maximumRecents;
@property BOOL sendsWholeSearchString;
@property (copy) NSArray<NSString *> *recentSearches;
@end

NS_ASSUME_NONNULL_END

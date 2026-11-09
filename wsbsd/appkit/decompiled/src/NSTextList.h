/*
 * NSTextList.h — 1:1 reimplementation (core). NSObject <NSSecureCoding, NSCopying>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextList : NSObject <NSSecureCoding, NSCopying> {
 *       @"NSString" _markerFormat;
 *       Q _listFlags;
 *       q _startIndex;
 *       ^v _listSecondary;
 *       @"NSTextAttachment" _markerTextAttachment;
 *   }
 *   @property (T@"NSString",R) markerFormat;
 *   @property (TQ,R) listOptions;
 *   @property (Tq) startingItemNumber;
 *   @property (TB,R,GisOrdered) ordered;
 *   -initWithMarkerFormat:options: -markerForItemNumber:
 *
 * A list marker template. markerForItemNumber: substitutes the item counter into
 * the marker format ({decimal}, {lower-roman}, {upper-alpha}, {disc}, …). The
 * marker text attachment (image bullets) is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSTextListOptions) {
    NSTextListPrependEnclosingMarker = 1 << 0,
};

@interface NSTextList : NSObject <NSCopying>

- (instancetype)initWithMarkerFormat:(NSString *)format options:(NSUInteger)mask;

@property (readonly, copy) NSString *markerFormat;
@property (readonly) NSTextListOptions listOptions;
@property NSInteger startingItemNumber;
@property (readonly, getter=isOrdered) BOOL ordered;

- (NSString *)markerForItemNumber:(NSInteger)itemNumber;

@end

NS_ASSUME_NONNULL_END

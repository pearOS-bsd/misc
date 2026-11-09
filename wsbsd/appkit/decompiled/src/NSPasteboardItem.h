/*
 * NSPasteboardItem.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSPasteboardItem : NSObject <NSPasteboardWriting, NSPasteboardReading> {
 *       @"NSPasteboard" _pasteboard;  Q _index;  q _gen;  @ _auxObject;
 *   }
 *   @property (T@"NSArray",R,C) types;
 *   -setData:forType: -dataForType: -setString:forType: -stringForType:
 *   -setPropertyList:forType: -propertyListForType: -availableTypeFromArray:
 *
 * One item on a pasteboard, carrying data under several UTI types. The core
 * stores the data in declaration order; strings use UTF-8 and property lists
 * round-trip through NSPropertyListSerialization. Data promises (providing data
 * lazily via a delegate) are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSPasteboardType NS_EXTENSIBLE_STRING_ENUM;

@interface NSPasteboardItem : NSObject

@property (readonly, copy) NSArray<NSPasteboardType> *types;
- (nullable NSPasteboardType)availableTypeFromArray:(NSArray<NSPasteboardType> *)types;

- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)type;
- (nullable NSData *)dataForType:(NSPasteboardType)type;
- (BOOL)setString:(NSString *)string forType:(NSPasteboardType)type;
- (nullable NSString *)stringForType:(NSPasteboardType)type;
- (BOOL)setPropertyList:(id)propertyList forType:(NSPasteboardType)type;
- (nullable id)propertyListForType:(NSPasteboardType)type;

@end

NS_ASSUME_NONNULL_END

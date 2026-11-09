/*
 * NSPasteboard.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSPasteboard : NSObject {
 *       q _gen;  @"NSMutableSet" _uniformTypeIdentifierSet;
 *       ^{__CFPasteboard} _pboard;  @"_NSPasteboardOwnersCollection" _owners;
 *       @"_NSPasteboardItemCollection" _pasteboardItems; …
 *   }
 *   +generalPasteboard +pasteboardWithName: -name -changeCount -clearContents
 *   -declareTypes:owner: -types -setString:forType: -stringForType:
 *   -setData:forType: -dataForType: -availableTypeFromArray:
 *
 * The real pasteboard is backed by CFPasteboard talking to pasteboardd. This
 * core models an in-process pasteboard (named registry, declared-type list,
 * type→data store, monotonic changeCount), which is the behavioural contract
 * apps rely on. The cross-process pasteboard server and promised data are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSPasteboardType NS_EXTENSIBLE_STRING_ENUM;
extern NSPasteboardType const NSPasteboardTypeString;

@interface NSPasteboard : NSObject

@property (class, readonly, strong) NSPasteboard *generalPasteboard;
+ (NSPasteboard *)pasteboardWithName:(NSString *)name;

@property (readonly) NSString *name;
@property (readonly) NSInteger changeCount;
@property (readonly, nullable, copy) NSArray<NSPasteboardType> *types;

- (NSInteger)clearContents;
- (NSInteger)declareTypes:(NSArray<NSPasteboardType> *)newTypes owner:(nullable id)newOwner;

- (BOOL)setString:(NSString *)string forType:(NSPasteboardType)dataType;
- (nullable NSString *)stringForType:(NSPasteboardType)dataType;
- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)dataType;
- (nullable NSData *)dataForType:(NSPasteboardType)dataType;
- (nullable NSPasteboardType)availableTypeFromArray:(NSArray<NSPasteboardType> *)types;

@end

NS_ASSUME_NONNULL_END

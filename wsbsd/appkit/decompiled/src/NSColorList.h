/*
 * NSColorList.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSColorList : NSObject <NSSecureCoding> {
 *       @"NSMutableArray" _keyArray;  @"NSMutableArray" _colorArray;
 *       ^{__CFDictionary} _keyToIndexTable;  @"NSString" _name;
 *       {_colorListFlags="colorsLoaded"b1"editable"b1 …"dirty"b1 …} _flags;
 *   }
 *   @property (T@"NSString",R,C) name;  (T@"NSArray",R,C) allKeys;
 *   @property (TB,R,GisEditable) editable;
 *   -initWithName: -colorWithKey: -setColor:forKey: -insertColor:key:atIndex:
 *   -removeColorWithKey: +availableColorLists
 *
 * An ordered key→colour mapping (parallel _keyArray/_colorArray with a
 * key→index table). The in-memory editing is exact; loading/saving .clr files
 * and the system colour lists (+availableColorLists / +colorListNamed:) are
 * stage2.
 */
#import <Foundation/Foundation.h>
#import "NSColor.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSColorList : NSObject

- (instancetype)initWithName:(NSString *)name;

@property (readonly) NSString *name;
@property (readonly, copy) NSArray<NSString *> *allKeys;
@property (readonly, getter=isEditable) BOOL editable;

- (void)setColor:(NSColor *)color forKey:(NSString *)key;
- (void)insertColor:(NSColor *)color key:(NSString *)key atIndex:(NSUInteger)loc;
- (void)removeColorWithKey:(NSString *)key;
- (nullable NSColor *)colorWithKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

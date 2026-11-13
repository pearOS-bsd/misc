/*
 * NSSortDescriptor.h — 1:1 reimplementation (behavioral core) of Foundation's
 * NSSortDescriptor.
 *
 * Interface evidence (real Foundation, macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSSortDescriptor_interface.txt. Standalone (uses KVC valueForKey:).
 */

#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSortDescriptor : NSObject <NSSecureCoding, NSCopying>

+ (instancetype)sortDescriptorWithKey:(nullable NSString *)key ascending:(BOOL)ascending;
+ (instancetype)sortDescriptorWithKey:(nullable NSString *)key ascending:(BOOL)ascending selector:(nullable SEL)selector;
- (instancetype)initWithKey:(nullable NSString *)key ascending:(BOOL)ascending;
- (instancetype)initWithKey:(nullable NSString *)key ascending:(BOOL)ascending selector:(nullable SEL)selector;

@property (readonly, nullable, copy) NSString *key;
@property (readonly) BOOL ascending;
@property (readonly, nullable) SEL selector;

- (id)reversedSortDescriptor;
- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2;

@end

NS_ASSUME_NONNULL_END

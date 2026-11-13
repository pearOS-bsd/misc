/*
 * NSNull.h — 1:1 reimplementation (behavioral core) of Foundation's NSNull,
 * the singleton stand-in for nil in collections.
 *
 * Interface evidence (real Foundation, macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSNull_interface.txt. Fully standalone; no CoreFoundation bridge.
 */

#import <Foundation/NSObject.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNull : NSObject <NSCopying, NSSecureCoding>
+ (NSNull *)null;
@end

NS_ASSUME_NONNULL_END

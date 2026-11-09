/*
 * NSAccessibilityCustomAction.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSAccessibilityCustomAction : NSObject {
 *       @"NSString" _name;  @"<NSObject>" _target;  @? _handler;  : _selector;
 *   }
 *   @property (T@"NSString",C) name;  (T@?,C) handler;  (weak) target;  (:) selector;
 *   -initWithName:handler: -initWithName:target:selector:
 *
 * A named custom accessibility action, invoked either through a handler block or
 * a target/selector. A value object; dispatching it to assistive technology is
 * stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAccessibilityCustomAction : NSObject

- (instancetype)initWithName:(NSString *)name handler:(BOOL (^)(void))handler;
- (instancetype)initWithName:(NSString *)name target:(id)target selector:(SEL)selector;

@property (copy) NSString *name;
@property (nullable, copy) BOOL (^handler)(void);
@property (nullable, weak) id target;
@property (nullable) SEL selector;

@end

NS_ASSUME_NONNULL_END

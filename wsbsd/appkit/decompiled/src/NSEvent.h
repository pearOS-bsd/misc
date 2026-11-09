/*
 * NSEvent.h — 1:1 reimplementation (core). NSObject <NSCopying, NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   +[NSEvent mouseEventWithType:location:modifierFlags:timestamp:windowNumber:
 *       context:eventNumber:clickCount:pressure:]
 *   +[NSEvent keyEventWithType:location:modifierFlags:timestamp:windowNumber:
 *       context:characters:charactersIgnoringModifiers:isARepeat:keyCode:]
 *   -type -modifierFlags -timestamp -locationInWindow -clickCount -buttonNumber
 *   -keyCode -characters -charactersIgnoringModifiers -isARepeat
 *
 * Immutable event objects built by the factory methods. The core models the
 * mouse and keyboard events apps read in the responder chain. CGEvent bridging,
 * the window-server event stream, tracking/periodic/tablet/gesture subtypes and
 * +addGlobalMonitor… are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSEventType) {
    NSEventTypeLeftMouseDown = 1,
    NSEventTypeLeftMouseUp = 2,
    NSEventTypeRightMouseDown = 3,
    NSEventTypeRightMouseUp = 4,
    NSEventTypeMouseMoved = 5,
    NSEventTypeLeftMouseDragged = 6,
    NSEventTypeRightMouseDragged = 7,
    NSEventTypeKeyDown = 10,
    NSEventTypeKeyUp = 11,
    NSEventTypeFlagsChanged = 12,
    NSEventTypeScrollWheel = 22,
};

typedef NS_OPTIONS(NSUInteger, NSEventModifierFlags) {
    NSEventModifierFlagCapsLock = 1 << 16,
    NSEventModifierFlagShift    = 1 << 17,
    NSEventModifierFlagControl  = 1 << 18,
    NSEventModifierFlagOption   = 1 << 19,
    NSEventModifierFlagCommand  = 1 << 20,
    NSEventModifierFlagFunction = 1 << 23,
};

@interface NSEvent : NSObject <NSCopying>

+ (nullable NSEvent *)mouseEventWithType:(NSEventType)type
                                location:(CGPoint)location
                           modifierFlags:(NSEventModifierFlags)flags
                               timestamp:(NSTimeInterval)time
                            windowNumber:(NSInteger)wNum
                                 context:(nullable id)context
                             eventNumber:(NSInteger)eNum
                              clickCount:(NSInteger)cNum
                                pressure:(float)pressure;

+ (nullable NSEvent *)keyEventWithType:(NSEventType)type
                              location:(CGPoint)location
                         modifierFlags:(NSEventModifierFlags)flags
                             timestamp:(NSTimeInterval)time
                          windowNumber:(NSInteger)wNum
                               context:(nullable id)context
                            characters:(NSString *)keys
           charactersIgnoringModifiers:(NSString *)ukeys
                             isARepeat:(BOOL)flag
                               keyCode:(unsigned short)code;

@property (readonly) NSEventType type;
@property (readonly) NSEventModifierFlags modifierFlags;
@property (readonly) NSTimeInterval timestamp;
@property (readonly) CGPoint locationInWindow;
@property (readonly) NSInteger windowNumber;
@property (readonly) NSInteger clickCount;
@property (readonly) NSInteger buttonNumber;
@property (readonly) float pressure;
@property (readonly) unsigned short keyCode;
@property (readonly, nullable, copy) NSString *characters;
@property (readonly, nullable, copy) NSString *charactersIgnoringModifiers;
@property (readonly, getter=isARepeat) BOOL ARepeat;

@end

NS_ASSUME_NONNULL_END

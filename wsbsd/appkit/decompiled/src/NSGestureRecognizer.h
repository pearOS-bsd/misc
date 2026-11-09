/*
 * NSGestureRecognizer.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/gr: target @0x20 (weak unless a flag @0xb8 bit 4 says
 * raw), action @0x28 (PAC-signed SEL), state packed in a word @0x58. isEnabled
 * is gated on the gestures framework being enabled. We expose the observable
 * state/enabled/target/action; the recognition state machine is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSGestureRecognizerState) {
    NSGestureRecognizerStatePossible = 0,
    NSGestureRecognizerStateBegan = 1,
    NSGestureRecognizerStateChanged = 2,
    NSGestureRecognizerStateEnded = 3,
    NSGestureRecognizerStateCancelled = 4,
    NSGestureRecognizerStateFailed = 5,
    NSGestureRecognizerStateRecognized = NSGestureRecognizerStateEnded,
};

@interface NSGestureRecognizer : NSObject
- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action;
@property (readonly) NSGestureRecognizerState state;
@property (getter=isEnabled) BOOL enabled;
@property (nullable, weak) id target;
@property (nullable) SEL action;
@end

NS_ASSUME_NONNULL_END

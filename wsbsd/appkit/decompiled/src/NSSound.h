/*
 * NSSound.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/sound: name @0x10, flags @0x40 (loops = bit 0, playing =
 * bit 1), volume @0x48 (float, clamped to [0,1]). Actual audio playback routes
 * through a player object (stage2).
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSound : NSObject
@property float volume;
@property BOOL loops;
@property (nullable, copy) NSString *name;
@property (getter=isPlaying, readonly) BOOL playing;
@end

NS_ASSUME_NONNULL_END

/*
 * NSSound.m — 1:1 (core). Evidence ../evidence/sound:
 * volume 0x185730f98 ([self+0x48]), setVolume: 0x1851cf408 (clamp to [0,1] then
 * push to the player), loops 0x185730fb8 (flags @0x40 bit 0), isPlaying
 * 0x185730c14 (flags bit 1), name 0x18506ad54 ([self+0x10]).
 */
#import "NSSound.h"

enum : uint8_t { NSSoundFlagLoops = 0x1, NSSoundFlagPlaying = 0x2 };

@implementation NSSound {
    NSString *_name;    /* 0x10 */
    uint8_t _flags;     /* 0x40 */
    float _volume;      /* 0x48 */
}

- (instancetype)init
{
    self = [super init];
    if (self) _volume = 1.0f;
    return self;
}

- (float)volume { return _volume; }
- (void)setVolume:(float)volume
{
    if (volume < 0.0f) volume = 0.0f;   /* fcsel pl */
    if (volume > 1.0f) volume = 1.0f;   /* fcsel gt */
    _volume = volume;
    /* TODO(stage2): push to the backing player. */
}

- (BOOL)loops { return (_flags & NSSoundFlagLoops) != 0; }
- (void)setLoops:(BOOL)loops
{
    _flags = (_flags & ~NSSoundFlagLoops) | (loops ? NSSoundFlagLoops : 0);
}

- (NSString *)name { return _name; }
- (void)setName:(NSString *)name { _name = [name copy]; }

- (BOOL)isPlaying { return (_flags & NSSoundFlagPlaying) != 0; }

@end

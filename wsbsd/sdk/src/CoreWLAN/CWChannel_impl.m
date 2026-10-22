/* CWChannel: a channel is a dictionary { CHANNEL, CHANNEL_FLAGS } of the Wi-Fi driver (Apple80211). Band and width come from the flags (table generated from the real framework,
 * tools/cwprobe), the description lists the widths the flags allow. Checked against the real CoreWLAN with tools/cwprobe/cwnet_probe chan (sdk/tests/cwlan_golden_test). */
#import <CoreWLAN/CoreWLAN_Generated.h>
#include "CWChannelTable.inc"

static void Lookup(unsigned long long flags, int *band, int *width)
{
	unsigned m = (unsigned)(flags & CW_CHANNEL_FLAGS_MASK);
	for (size_t i = 0; i < sizeof kChannelFlagsTable / sizeof kChannelFlagsTable[0]; i++) if (kChannelFlagsTable[i].flags == m) { *band = kChannelFlagsTable[i].band; *width = kChannelFlagsTable[i].width; return; }
	*band = 0; *width = 0;
}

@implementation CWChannel (Impl)
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithInfo:(NSDictionary *)info { if ((self = [super init])) { _info = [info copy]; } return self; }
- (instancetype)initWithChannel:(CWChannel *)c
{
	if ((self = [super init])) { NSNumber *n = [[c info] objectForKey: @"CHANNEL"], *f = [[c info] objectForKey: @"CHANNEL_FLAGS"]; NSMutableDictionary *d = [NSMutableDictionary dictionary]; if (n) d[@"CHANNEL"] = n; if (f) d[@"CHANNEL_FLAGS"] = f; _info = [d copy]; }
	return self;
}
- (instancetype)initWithCoder:(NSCoder *)c
{
	if ((self = [super init])) _info = [[c decodeObjectOfClasses: [NSSet setWithObjects: [NSDictionary class], [NSString class], [NSNumber class], nil] forKey: @"_info"] copy];
	return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: _info forKey: @"_info"]; }
- (id)copyWithZone:(NSZone *)z { return [[CWChannel allocWithZone: z] initWithChannel: self]; }
- (NSDictionary *)info { return _info; }
- (void)setInfo:(NSDictionary *)i { if (_info != i) { [_info release]; _info = [i copy]; } }
- (NSInteger)channelNumber { return [_info[@"CHANNEL"] longLongValue]; }
- (unsigned long long)flags { return (unsigned long long)[_info[@"CHANNEL_FLAGS"] longLongValue]; }
- (long long)channelWidth { int b, w; Lookup([self flags], &b, &w); return w; }
- (long long)channelBand { int b, w; Lookup([self flags], &b, &w); return b; }
- (BOOL)isEqualToChannel:(CWChannel *)o { return o && [self channelNumber] == [o channelNumber] && [self flags] == [o flags]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass: [CWChannel class]] && [self isEqualToChannel: o]); }
- (NSUInteger)hash { int b, w; Lookup([self flags], &b, &w); return (NSUInteger)([self channelNumber] ^ (b ^ w)); }
- (NSString *)description
{
	unsigned long long f = [self flags]; int b, w; Lookup(f, &b, &w); NSString *band = b == 1 ? @"(2GHz)" : b == 2 ? @"(5GHz)" : b == 3 ? @"(6GHz)" : @"";
	NSMutableString *ws = [NSMutableString string];
	if (f & 0x1) [ws appendString: @"10MHz"];
	if (f & 0x2) [ws appendFormat: @"%@20MHz", [ws length] ? @", " : @""];
	if (f & 0x4) [ws appendFormat: @"%@40MHz(%@1)", [ws length] ? @", " : @"", (f & 0x200) ? @"+" : @"-"];
	if (f & 0x400) [ws appendString: @"80MHz"];
	if (f & 0x800) [ws appendString: @"160MHz"];
	return [NSString stringWithFormat: @"<%@: %p> [channelNumber=%ld%@, channelWidth={%@}%@%@%@]", NSStringFromClass([self class]), self, (long)[self channelNumber], band, ws, (f & 0x80) ? @", active" : @"", (f & 0x100) ? @", DFS" : @"", ((f & 0x2000) && (f & 0x2) && [self channelNumber] % 16 == 5) ? @", PSC" : @""];
}
- (unsigned long long)channelProperties
{
	unsigned long long f = [self flags], p = 0; long n = [self channelNumber];
	if (f & 0x1) p |= 2; else if (f & 0x2) p |= 4; else if (f & 0x4) p |= 8; else if (f & 0x400) p |= 1024; else if (f & 0x800) p |= 2048;      /* the narrowest width flag wins */
	if (f & 0x8) p |= 16; else if (f & 0x10) p |= 32; else if (f & 0x2000) p |= 4096;                                                             /* 2.4, 5, 6 GHz */
	if (f & 0x100) p |= 256; else if (f & 0x80) p |= 512;                                                                                           /* DFS before active */
	if (p & 4) { if ((n >= 1 && n <= 11) || n == 36 || n == 40 || n == 44 || n == 48) p |= 192; }                                                  /* 20 MHz on the channels of the first two sub-bands */
	return p;
}
@end

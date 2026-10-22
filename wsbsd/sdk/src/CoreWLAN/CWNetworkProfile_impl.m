/* CWNetworkProfile / CWMutableNetworkProfile: a known network. Security and security type convert with the tables measured on the real framework (CWProfileTables.inc). */
#import <CoreWLAN/CoreWLAN_Generated.h>
#include "CWProfileTables.inc"

static unsigned long long TypeForSecurity(long long s) { for (size_t i = 0; i < sizeof kProfileSecurityToType / sizeof kProfileSecurityToType[0]; i++) if (kProfileSecurityToType[i].security == s) return kProfileSecurityToType[i].type; return 0; }
static long long SecurityForType(unsigned long long t) { long long r = 9223372036854775807LL; for (size_t i = 0; i < sizeof kProfileTypeToSecurity / sizeof kProfileTypeToSecurity[0]; i++) { if (kProfileTypeToSecurity[i].type <= t) r = kProfileTypeToSecurity[i].security; else break; } return r; }

@implementation CWNetworkProfile (Impl)
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)networkProfile { return [[[self alloc] init] autorelease]; }
+ (instancetype)networkProfileWithNetworkProfile:(CWNetworkProfile *)p { return [[[self alloc] initWithNetworkProfile: p] autorelease]; }
- (instancetype)init { if ((self = [super init])) _isServiceProviderRoamingEnabled = YES; return self; }
- (instancetype)initWithNetworkProfile:(CWNetworkProfile *)p { if ((self = [self init])) { if (p) { _ssidData = [[p ssidData] copy]; _ssid = [[p ssid] copy]; _securityType = [p securityType]; _disabled = [p disabled]; _hiddenNetwork = [p hiddenNetwork]; _lastAutoJoinAt = [[p lastAutoJoinAt] copy]; _lastManualJoinAt = [[p lastManualJoinAt] copy]; _addedAt = [[p addedAt] copy]; _systemMode = [p systemMode]; _isPersonalHotspot = [p isPersonalHotspot]; } } return self; }
- (id)copyWithZone:(NSZone *)z { return [[CWNetworkProfile allocWithZone: z] initWithNetworkProfile: self]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[CWMutableNetworkProfile allocWithZone: z] initWithNetworkProfile: self]; }
- (NSData *)ssidData { return _ssidData; }
- (void)setSsidData:(NSData *)d { if (_ssidData != d) { [_ssidData release]; _ssidData = [d copy]; } [_ssid release]; _ssid = d ? [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding] : nil; }
- (long long)security { return SecurityForType(_securityType); }
- (void)setSecurity:(long long)s { _securityType = TypeForSecurity(s); }
- (unsigned long long)securityType { return _securityType; }
- (void)setSecurityType:(unsigned long long)t { _securityType = t; }
- (NSDate *)lastConnected { NSDate *a = _lastAutoJoinAt, *m = _lastManualJoinAt; if (a && m) return [a compare: m] == NSOrderedAscending ? m : a; return a ?: m; }
- (BOOL)captiveNetwork { return _captiveNetworkStatus != 0; } - (void)setCaptiveNetwork:(BOOL)b { _captiveNetworkStatus = b ? 1 : 0; }
- (BOOL)autoLogin { return !_disabled; } - (void)setAutoLogin:(BOOL)b { _disabled = !b; }
- (long long)shareMode { return _shareMode; } - (void)setShareMode:(long long)v { _shareMode = v; }
- (long long)movingAttribute { return _movingAttribute; } - (void)setMovingAttribute:(long long)v { _movingAttribute = v; }
- (long long)publicAttribute { return _publicAttribute; } - (void)setPublicAttribute:(long long)v { _publicAttribute = v; }
- (unsigned long long)lowDataMode { return _lowDataMode; } - (void)setLowDataMode:(unsigned long long)v { _lowDataMode = v; }
- (BOOL)isEqualToNetworkProfile:(CWNetworkProfile *)o { return o && [_ssidData isEqual: [o ssidData]] == YES && _securityType == [o securityType] ? YES : (!_ssidData && ![o ssidData] && _securityType == [o securityType]); }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass: [CWNetworkProfile class]] && [self isEqualToNetworkProfile: o]); }
- (NSUInteger)hash { return [_ssidData hash] ^ (NSUInteger)_securityType; }
- (NSString *)description
{
	NSString *ssid = _ssidData ? [NSString stringWithFormat: @"%@ (%@)", _ssid, _ssidData] : @"(null) ((null))";
	return [NSString stringWithFormat: @"SSID: %@\nCaptive: %@\nWas Captive: %@\nDomain Name: %@\nPasspoint: %@\nDisplay Name: %@\nRoaming Consortium List: %@\nNAI Realm List: %@\nSP Roaming Enabled: %@\nSecurity: %@\nHidden: %@\nPossibly Hidden: %@\nWas Hidden Before: %@\nSystem Mode: %@\nRoaming Profile Type: None\nPersonal Hotspot: %@\nBSSID List: %@\nShare Mode: NotSupported\nUser Role: Owner\nPayloadUUID: %@\n",
		ssid, _captiveNetworkStatus ? @"Yes" : @"No", _wasCaptiveNetwork ? @"Yes" : @"No", _domainName, _isPasspoint ? @"Yes" : @"No", _displayName, _roamingConsortiumList, _naiRealmList, _isServiceProviderRoamingEnabled ? @"Yes" : @"No", nil, _hiddenNetwork ? @"Yes" : @"No", _possiblyHiddenNetwork ? @"Yes" : @"No", _wasHiddenBefore ? @"Yes" : @"No", _systemMode ? @"Yes" : @"No", _isPersonalHotspot ? @"Yes" : @"No", _bssidList, _payloadUUID];
}
- (NSString *)identifier { return nil; }
@end

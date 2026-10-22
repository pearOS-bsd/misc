/* CWNetworkProfile / CWMutableNetworkProfile: a known network. Security and security type convert with the tables measured on the real framework (CWProfileTables.inc). */
#import <CoreWLAN/CoreWLAN_Generated.h>
#import <objc/runtime.h>
#include "CWProfileTables.inc"

static unsigned long long TypeForSecurity(long long s) { for (size_t i = 0; i < sizeof kProfileSecurityToType / sizeof kProfileSecurityToType[0]; i++) if (kProfileSecurityToType[i].security == s) return kProfileSecurityToType[i].type; return 0; }
static long long SecurityForType(unsigned long long t) { long long r = 9223372036854775807LL; for (size_t i = 0; i < sizeof kProfileTypeToSecurity / sizeof kProfileTypeToSecurity[0]; i++) { if (kProfileTypeToSecurity[i].type <= t) r = kProfileTypeToSecurity[i].security; else break; } return r; }

/* NSData's description as the Mac prints it: "{length = N, bytes = 0x..}" in groups of four bytes, the middle left out above 24 bytes */
static NSString *DataText(NSData *d)
{
	NSUInteger n = [d length]; const unsigned char *b = [d bytes]; NSMutableString *h = [NSMutableString string];
	#define GROUP(from, to) for (NSUInteger i = (from); i < (to); i++) { [h appendFormat: @"%02x", b[i]]; if ((i - (from)) % 4 == 3 && i + 1 < (to)) [h appendString: @" "]; }
	if (n <= 24) { for (NSUInteger i = 0; i < n; i++) [h appendFormat: @"%02x", b[i]]; }
	else { GROUP(0, 16) [h appendString: @" ... "]; GROUP(n - 8, n) [h appendString: @" "]; }
	return [NSString stringWithFormat: @"{length = %lu, bytes = 0x%@}", (unsigned long)n, h];
}
static NSString *Hex(NSData *d);
static NSString *ListText(id l) { if (!l) return @"(null)"; NSMutableString *r = [NSMutableString stringWithString: @"("]; NSUInteger n = [l count], i = 0; for (id o in l) { [r appendFormat: @"\n    %@%s", o, ++i < n ? "," : ""]; } [r appendString: @"\n)"]; return r; }
static NSString *SecurityText(unsigned long long type)
{
	long long sec = SecurityForType(type); NSString *t = nil;
	switch (type) { case 2: t = @"Open"; break; case 4: t = @"WEP40 OpenSystem"; break; case 8: t = @"WEP104 OpenSystem"; break; case 16: t = @"WEP40 SharedKey"; break; case 32: t = @"WEP104 SharedKey"; break; default: break; }
	if (!t) switch (sec) { case 0: t = @"Open"; break; case 1: t = @"WEP"; break; case 3: t = @"WPA/WPA2 Personal"; break; case 6: t = @"WEP Enterprise"; break; case 8: t = @"WPA/WPA2 Enterprise"; break; case 9: t = @"WPA2 Enterprise"; break; case 11: t = @"WPA3 Personal"; break; case 12: t = @"WPA3 Enterprise"; break; case 13: t = @"WPA2/WPA3 Personal"; break; case 14: t = @"OWE"; break; case 15: t = @"OPEN/OWE"; break; default: break; }
	return t;
}
static BOOL TypeForText(NSString *t, unsigned long long *type)
{
	static const struct { const char *text; long long sec; unsigned long long type; } m[] = { { "Open", 0, 0 }, { "WEP40 OpenSystem", 0, 4 }, { "WEP104 OpenSystem", 0, 8 }, { "WEP40 SharedKey", 0, 16 }, { "WEP104 SharedKey", 0, 32 }, { "WEP", 1, 0 }, { "WPA/WPA2 Personal", 3, 0 }, { "WEP Enterprise", 6, 0 }, { "WPA/WPA2 Enterprise", 8, 0 }, { "WPA2 Enterprise", 9, 0 }, { "WPA3 Personal", 11, 0 }, { "WPA3 Enterprise", 12, 0 }, { "WPA2/WPA3 Personal", 13, 0 }, { "OWE", 14, 0 }, { "OPEN/OWE", 15, 0 } };
	for (size_t i = 0; i < sizeof m / sizeof m[0]; i++) if (!strcmp(m[i].text, [t UTF8String])) { *type = m[i].type ? m[i].type : TypeForSecurity(m[i].sec); return YES; }
	return NO;
}
static BOOL Personal(long long security) { return security == 2 || security == 3 || security == 4 || security == 5 || security == 11 || security == 13 || security == 3; }
static NSString *ShareText(long long m) { switch (m) { case 0: return @"None"; case 1: return @"NotSupported"; case 2: return @"Disabled"; case 3: return @"Enabled"; } return @"None"; }

@implementation CWNetworkProfile (Impl)
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)networkProfile { return [[[self alloc] init] autorelease]; }
+ (instancetype)networkProfileWithNetworkProfile:(CWNetworkProfile *)p { return [[[self alloc] initWithNetworkProfile: p] autorelease]; }
- (instancetype)init { if ((self = [super init])) { _isServiceProviderRoamingEnabled = YES; _privacyProxyEnabled = YES; _shareMode = 1; _userRole = 1; _collocatedGroup = [[NSSet alloc] init]; _channelHistory = [[NSSet alloc] init]; } return self; }
- (instancetype)initWithNetworkProfile:(CWNetworkProfile *)p
{
	if ((self = [self init]) && p) {
		unsigned int n = 0; Ivar *iv = class_copyIvarList([CWNetworkProfile class], &n);
		for (unsigned int i = 0; i < n; i++) { const char *t = ivar_getTypeEncoding(iv[i]); if (t[0] == '@') { id o = object_getIvar(p, iv[i]), old = object_getIvar(self, iv[i]); if (o != old) { id c = [o copy]; [old release]; object_setIvar(self, iv[i], c); } } else { ptrdiff_t off = ivar_getOffset(iv[i]); NSUInteger sz; NSGetSizeAndAlignment(t, &sz, NULL); memcpy((char *)self + off, (char *)p + off, sz); } }
		free(iv);
	}
	return self;
}
- (id)copyWithZone:(NSZone *)z { return [[CWNetworkProfile allocWithZone: z] initWithNetworkProfile: self]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[CWMutableNetworkProfile allocWithZone: z] initWithNetworkProfile: self]; }
- (NSData *)ssidData { return _ssidData; }
- (void)setSsidData:(NSData *)d
{
	if (_ssidData != d) { [_ssidData release]; _ssidData = [d copy]; }
	[_ssid release]; _ssid = nil;
	if ([d length]) { _ssid = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; if (!_ssid) _ssid = [[NSString alloc] initWithData: d encoding: NSISOLatin1StringEncoding]; }
}
- (long long)security { return SecurityForType(_securityType); }
- (void)setSecurity:(long long)s { _securityType = TypeForSecurity(s); long long now = SecurityForType(_securityType); _shareMode = Personal(now) ? 3 : 1; }
- (unsigned long long)securityType { return _securityType; }
- (void)setSecurityType:(unsigned long long)t { _securityType = t == 64 ? 192 : t == 128 ? 4224 : t; long long now = SecurityForType(t); _shareMode = Personal(now) ? 3 : 1; }
- (NSDate *)lastConnected { NSDate *a = _lastAutoJoinAt, *m = _lastManualJoinAt; if (a && m) return [a compare: m] == NSOrderedAscending ? m : a; return a ?: m; }
- (void)setWasCaptiveNetwork:(BOOL)b { }
- (BOOL)captiveNetwork { return NO; } - (void)setCaptiveNetwork:(BOOL)b { _captiveNetworkStatus = b ? 2 : 1; }
- (BOOL)autoLogin { return !_captiveBypass; } - (void)setAutoLogin:(BOOL)b { _captiveBypass = !b; }
- (long long)shareMode { return _shareMode; }
- (void)setShareMode:(long long)v { if (Personal(SecurityForType(_securityType))) _shareMode = v; }
- (long long)movingAttribute { return _movingAttribute; } - (void)setMovingAttribute:(long long)v { _movingAttribute = v; }
- (long long)publicAttribute { return _publicAttribute; } - (void)setPublicAttribute:(long long)v { _publicAttribute = v; }
- (unsigned long long)lowDataMode { return _lowDataMode; } - (void)setLowDataMode:(unsigned long long)v { _lowDataMode = v; }
- (NSString *)identifier { return _isPasspoint ? [NSString stringWithFormat: @"wifi.passpoint.%@", _domainName] : _ssidData ? [NSString stringWithFormat: @"wifi.ssid.%@", Hex(_ssidData)] : @"wifi.ssid.(null)"; }
static NSString *Hex(NSData *d) { NSMutableString *h = [NSMutableString string]; const unsigned char *b = [d bytes]; for (NSUInteger i = 0; i < [d length]; i++) [h appendFormat: @"%02x", b[i]]; return h; }
- (BOOL)isEqualToNetworkProfile:(CWNetworkProfile *)o { return o && _ssidData && [_ssidData isEqual: [o ssidData]] && [[self identifier] isEqual: [o identifier]]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass: [CWNetworkProfile class]] && [self isEqualToNetworkProfile: o]); }
- (NSUInteger)hash { return [[self identifier] hash]; }

/* the dictionary of the known-networks preferences: the keys the real framework writes (and nothing for what is unset) */
#define PUT(key, val) do { id v_ = (val); if (v_) d[@key] = v_; } while (0)
- (NSDictionary *)externalForm
{
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	PUT("LastAutoJoinAt", _lastAutoJoinAt); PUT("LastManualJoinAt", _lastManualJoinAt); if (_captiveNetworkStatus) d[@"Captive"] = @NO;
	d[@"TemporarilyDisabled"] = @(_temporarilyDisabled); d[@"SystemMode"] = @(_systemMode); d[@"HiddenNetwork"] = @(_hiddenNetwork); d[@"CaptiveBypass"] = @(_captiveBypass); d[@"Disabled"] = @(_disabled); d[@"Passpoint"] = @(_isPasspoint);
	PUT("DomainName", _domainName); PUT("DisplayName", _displayName); PUT("RoamingConsortiumList", _roamingConsortiumList); PUT("NAIRealmList", _naiRealmList);
	d[@"SPRoaming"] = @(_isServiceProviderRoamingEnabled); d[@"PossiblyHiddenNetwork"] = @(_possiblyHiddenNetwork); d[@"CollocatedGroup"] = [_collocatedGroup allObjects] ?: @[]; d[@"ChannelHistory"] = [_channelHistory allObjects] ?: @[];
	d[@"RoamingProfileType"] = _roamingProfileType == 2 ? @"Single" : _roamingProfileType == 3 ? @"Dual" : @"None"; d[@"TransitionDisabledFlags"] = @(_transitionDisabledFlags); d[@"Standalone6G"] = @(_standalone6G); d[@"PersonalHotspot"] = @(_isPersonalHotspot);
	PUT("BSSIDList", _bssidList); d[@"ShareMode"] = @(_shareMode); d[@"UserRole"] = @(_userRole); PUT("PayloadUUID", _payloadUUID); d[@"AddedBy"] = @(_addedBy); PUT("AddedAt", _addedAt); PUT("WasHiddenBefore", _wasHiddenBefore);
	PUT("CaptiveWebSheetLoginDate", _captiveSheetTimestamp); PUT("UserPreferredOrderTimestamp", _userPreferredOrderTimestamp); PUT("UpdatedAt", _updatedAt); PUT("DiscoveredAt", _discoveredAt); PUT("NetworkGroupID", _networkGroupID);
	if (_networkGroupPriority) d[@"NetworkGroupPriority"] = @(_networkGroupPriority); PUT("UserPreferredNetworkNames", _userPreferredNetworkNames); PUT("UserPreferredPasspointDomains", _userPreferredPasspointDomains);
	d[@"PrivacyProxyEnabled"] = @(_privacyProxyEnabled); d[@"MovingAttribute"] = @(_movingAttribute); d[@"PublicAttribute"] = @(_publicAttribute); d[@"LowDataMode"] = @(_lowDataMode); d[@"NetworkWasCaptive"] = @(_wasCaptiveNetwork);
	PUT("SSID", _ssidData); PUT("SSIDString", _ssid); PUT("SecurityType", SecurityText(_securityType));
	return d;
}
#define GET(ivar, key, conv) do { id v_ = e[@key]; if (v_) ivar = conv; } while (0)
- (instancetype)initWithExternalForm:(NSDictionary *)e
{
	if ((self = [self init]) && [e isKindOfClass: [NSDictionary class]]) {
		GET(_lastAutoJoinAt, "LastAutoJoinAt", [v_ copy]); GET(_lastManualJoinAt, "LastManualJoinAt", [v_ copy]); GET(_temporarilyDisabled, "TemporarilyDisabled", [v_ boolValue]); GET(_systemMode, "SystemMode", [v_ boolValue]); GET(_hiddenNetwork, "HiddenNetwork", [v_ boolValue]);
		GET(_captiveBypass, "CaptiveBypass", [v_ boolValue]); GET(_disabled, "Disabled", [v_ boolValue]); GET(_isPasspoint, "Passpoint", [v_ boolValue]); GET(_domainName, "DomainName", [v_ copy]); GET(_displayName, "DisplayName", [v_ copy]);
		GET(_roamingConsortiumList, "RoamingConsortiumList", [v_ copy]); GET(_naiRealmList, "NAIRealmList", [v_ copy]); GET(_isServiceProviderRoamingEnabled, "SPRoaming", [v_ boolValue]); GET(_possiblyHiddenNetwork, "PossiblyHiddenNetwork", [v_ boolValue]);
		if (e[@"CollocatedGroup"]) { [_collocatedGroup release]; _collocatedGroup = [[NSSet alloc] initWithArray: e[@"CollocatedGroup"]]; } if (e[@"ChannelHistory"]) { [_channelHistory release]; _channelHistory = [[NSSet alloc] initWithArray: e[@"ChannelHistory"]]; }
		if (e[@"RoamingProfileType"]) _roamingProfileType = [e[@"RoamingProfileType"] isEqual: @"Single"] ? 2 : [e[@"RoamingProfileType"] isEqual: @"Dual"] ? 3 : 0;
		GET(_transitionDisabledFlags, "TransitionDisabledFlags", [v_ unsignedLongLongValue]); GET(_standalone6G, "Standalone6G", [v_ boolValue]); GET(_isPersonalHotspot, "PersonalHotspot", [v_ boolValue]); GET(_bssidList, "BSSIDList", [v_ copy]);
		GET(_shareMode, "ShareMode", [v_ longLongValue]); GET(_userRole, "UserRole", [v_ longLongValue]); GET(_payloadUUID, "PayloadUUID", [v_ copy]); GET(_addedBy, "AddedBy", [v_ unsignedLongLongValue]); GET(_addedAt, "AddedAt", [v_ copy]); GET(_wasHiddenBefore, "WasHiddenBefore", [v_ copy]);
		GET(_captiveSheetTimestamp, "CaptiveWebSheetLoginDate", [v_ copy]); GET(_userPreferredOrderTimestamp, "UserPreferredOrderTimestamp", [v_ copy]); GET(_updatedAt, "UpdatedAt", [v_ copy]); GET(_discoveredAt, "DiscoveredAt", [v_ copy]); GET(_networkGroupID, "NetworkGroupID", [v_ copy]);
		GET(_networkGroupPriority, "NetworkGroupPriority", [v_ unsignedLongLongValue]); GET(_userPreferredNetworkNames, "UserPreferredNetworkNames", [v_ copy]); GET(_userPreferredPasspointDomains, "UserPreferredPasspointDomains", [v_ copy]);
		GET(_privacyProxyEnabled, "PrivacyProxyEnabled", [v_ boolValue]); GET(_movingAttribute, "MovingAttribute", [v_ longLongValue]); GET(_publicAttribute, "PublicAttribute", [v_ longLongValue]); GET(_lowDataMode, "LowDataMode", [v_ unsignedLongLongValue]); GET(_wasCaptiveNetwork, "NetworkWasCaptive", [v_ boolValue]);
		if (e[@"Captive"]) _captiveNetworkStatus = [e[@"Captive"] boolValue] ? 2 : 1;
		if (e[@"SSID"]) [self setSsidData: e[@"SSID"]];
		if ([e[@"SecurityType"] isKindOfClass: [NSString class]]) { unsigned long long t; if (TypeForText(e[@"SecurityType"], &t)) _securityType = t; }
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: [self externalForm] forKey: @"_externalForm"]; }
- (instancetype)initWithCoder:(NSCoder *)c
{
	NSSet *classes = [NSSet setWithObjects: [NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], [NSDate class], [NSSet class], nil];
	return [self initWithExternalForm: [c decodeObjectOfClasses: classes forKey: @"_externalForm"]];
}
- (NSString *)description
{
	NSString *ssid = [NSString stringWithFormat: @"%@ (%@)", _ssid, _ssidData ? DataText(_ssidData) : nil];
	NSString *secText = SecurityText(_securityType);
	NSString *role = _userRole == 1 ? @"Owner" : _userRole == 2 ? @"Guest" : @"None", *roam = _roamingProfileType == 2 ? @"Single" : _roamingProfileType == 3 ? @"Dual" : @"None";
	return [NSString stringWithFormat: @"SSID: %@\nCaptive: %@\nWas Captive: %@\nDomain Name: %@\nPasspoint: %@\nDisplay Name: %@\nRoaming Consortium List: %@\nNAI Realm List: %@\nSP Roaming Enabled: %@\nSecurity: %@\nHidden: %@\nPossibly Hidden: %@\nWas Hidden Before: %@\nSystem Mode: %@\nRoaming Profile Type: %@\nPersonal Hotspot: %@\nBSSID List: %@\nShare Mode: %@\nUser Role: %@\nPayloadUUID: %@\n",
		_ssidData ? ssid : @"(null) ((null))", @"No", @"No", _domainName, _isPasspoint ? @"Yes" : @"No", _displayName, ListText(_roamingConsortiumList), ListText(_naiRealmList), _isServiceProviderRoamingEnabled ? @"Yes" : @"No", secText, _hiddenNetwork ? @"Yes" : @"No", _possiblyHiddenNetwork ? @"Yes" : @"No", _wasHiddenBefore ? @"Yes" : @"No", _systemMode ? @"Yes" : @"No", roam, _isPersonalHotspot ? @"Yes" : @"No", ListText(_bssidList), ShareText(_shareMode), role, _payloadUUID];
}
@end

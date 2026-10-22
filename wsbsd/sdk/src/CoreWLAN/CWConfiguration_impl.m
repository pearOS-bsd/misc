/* CWConfiguration / CWMutableConfiguration: the Wi-Fi preferences of an interface: the known networks in the order of preference and four flags. */
#import <CoreWLAN/CoreWLAN_Generated.h>
@implementation CWConfiguration (Impl)
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)configuration { return [[[self alloc] init] autorelease]; }
+ (instancetype)configurationWithConfiguration:(CWConfiguration *)c { return [[[self alloc] initWithConfiguration: c] autorelease]; }
+ (instancetype)configurationForInterfaceWithName:(NSString *)n { return [[[self alloc] initForInterfaceWithName: n] autorelease]; }
- (instancetype)init { if ((self = [super init])) { _networkProfiles = [[NSOrderedSet alloc] init]; _rememberJoinedNetworks = YES; } return self; }
- (instancetype)initForInterfaceWithName:(NSString *)n { return [self init]; }
- (instancetype)initWithConfiguration:(CWConfiguration *)c { if ((self = [self init])) { if (c) { [_networkProfiles release]; _networkProfiles = [[c networkProfiles] copy]; _rememberJoinedNetworks = [c rememberJoinedNetworks]; _requireAdministratorForAssociation = [c requireAdministratorForAssociation]; _requireAdministratorForPower = [c requireAdministratorForPower]; _requireAdministratorForIBSSMode = [c requireAdministratorForIBSSMode]; } } return self; }
- (instancetype)initWithInfo:(NSDictionary *)info knownNetworks:(NSArray *)k { return [self init]; }
- (id)copyWithZone:(NSZone *)z { return [[CWConfiguration allocWithZone: z] initWithConfiguration: self]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[CWMutableConfiguration allocWithZone: z] initWithConfiguration: self]; }
- (NSOrderedSet *)networkProfiles { return _networkProfiles; }
- (void)setNetworkProfiles:(NSOrderedSet *)s { if (_networkProfiles != s) { [_networkProfiles release]; _networkProfiles = [s copy]; } }
- (NSArray *)preferredNetworks { return [_networkProfiles array]; }
- (BOOL)rememberJoinedNetworks { return _rememberJoinedNetworks; } - (void)setRememberJoinedNetworks:(BOOL)b { _rememberJoinedNetworks = b; }
- (BOOL)requireAdministratorForAssociation { return _requireAdministratorForAssociation; } - (void)setRequireAdministratorForAssociation:(BOOL)b { _requireAdministratorForAssociation = b; }
- (BOOL)requireAdministratorForPower { return _requireAdministratorForPower; } - (void)setRequireAdministratorForPower:(BOOL)b { _requireAdministratorForPower = b; }
- (BOOL)requireAdministratorForIBSSMode { return _requireAdministratorForIBSSMode; } - (void)setRequireAdministratorForIBSSMode:(BOOL)b { _requireAdministratorForIBSSMode = b; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: _info forKey: @"_info"]; [c encodeObject: _networkProfiles forKey: @"_networkProfiles"]; [c encodeBool: _requireAdministratorForAssociation forKey: @"_requireAdministratorForAssociation"]; [c encodeBool: _requireAdministratorForPower forKey: @"_requireAdministratorForPower"]; [c encodeBool: _requireAdministratorForIBSSMode forKey: @"_requireAdministratorForIBSSMode"]; [c encodeBool: _rememberJoinedNetworks forKey: @"_rememberJoinedNetworks"]; }
- (instancetype)initWithCoder:(NSCoder *)c
{
	if ((self = [self init])) {
		_info = [[c decodeObjectOfClasses: [NSSet setWithObjects: [NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], [NSDate class], nil] forKey: @"_info"] retain];
		NSOrderedSet *p = [c decodeObjectOfClasses: [NSSet setWithObjects: [NSOrderedSet class], [CWNetworkProfile class], nil] forKey: @"_networkProfiles"]; if (p) { [_networkProfiles release]; _networkProfiles = [p copy]; }
		_requireAdministratorForAssociation = [c decodeBoolForKey: @"_requireAdministratorForAssociation"]; _requireAdministratorForPower = [c decodeBoolForKey: @"_requireAdministratorForPower"]; _requireAdministratorForIBSSMode = [c decodeBoolForKey: @"_requireAdministratorForIBSSMode"]; _rememberJoinedNetworks = [c decodeBoolForKey: @"_rememberJoinedNetworks"];
	}
	return self;
}
- (BOOL)isEqualToConfiguration:(CWConfiguration *)o { return o && [[self networkProfiles] isEqual: [o networkProfiles]] && _rememberJoinedNetworks == [o rememberJoinedNetworks] && _requireAdministratorForAssociation == [o requireAdministratorForAssociation] && _requireAdministratorForPower == [o requireAdministratorForPower] && _requireAdministratorForIBSSMode == [o requireAdministratorForIBSSMode]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass: [CWConfiguration class]] && [self isEqualToConfiguration: o]); }
- (NSUInteger)hash { return [_networkProfiles hash]; }
- (NSString *)description { return [NSString stringWithFormat: @"<%@: %p>", NSStringFromClass([self class]), self]; }
@end

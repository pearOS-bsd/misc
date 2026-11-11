/*
 * NSWorkspaceOpenConfiguration.m — 1:1 value object. See the header.
 */

#import "NSWorkspaceOpenConfiguration.h"

@implementation NSWorkspaceOpenConfiguration {
    NSArray<NSString *> *_arguments;
    NSDictionary<NSString *, NSString *> *_environment;
}

+ (instancetype)configuration { return [[self alloc] init]; }

- (instancetype)init
{
    self = [super init];
    if (self) {
        _promptsUserIfNeeded = YES;
        _addsToRecentItems = YES;
        _activates = YES;
        _hides = NO;
        _hidesOthers = NO;
        _forPrinting = NO;
        _createsNewApplicationInstance = NO;
        _allowsRunningApplicationSubstitution = YES;
        _requiresUniversalLinks = NO;
        _architecture = -1;              /* measured */
        _arguments = @[];
        _environment = @{};
    }
    return self;
}

- (NSArray<NSString *> *)arguments { return _arguments; }
- (void)setArguments:(NSArray<NSString *> *)a { _arguments = [a copy] ?: @[]; }

- (NSDictionary<NSString *, NSString *> *)environment { return _environment; }
- (void)setEnvironment:(NSDictionary<NSString *, NSString *> *)e { _environment = [e copy] ?: @{}; }

- (id)copyWithZone:(NSZone *)zone
{
    NSWorkspaceOpenConfiguration *c = [[[self class] alloc] init];
    c->_promptsUserIfNeeded = _promptsUserIfNeeded;
    c->_addsToRecentItems = _addsToRecentItems;
    c->_activates = _activates;
    c->_hides = _hides;
    c->_hidesOthers = _hidesOthers;
    c->_forPrinting = _forPrinting;
    c->_createsNewApplicationInstance = _createsNewApplicationInstance;
    c->_allowsRunningApplicationSubstitution = _allowsRunningApplicationSubstitution;
    c->_requiresUniversalLinks = _requiresUniversalLinks;
    c->_architecture = _architecture;
    c->_arguments = [_arguments copy];
    c->_environment = [_environment copy];
    c->_appleEvent = _appleEvent;
    return c;
}

@end

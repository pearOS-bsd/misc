/*
 * NSTintConfiguration.m — 1:1 (core). See the header for the interface evidence.
 *
 * _type is one of default / monochrome / fixed-colour / preferred-colour.
 * baseTintColor is the stored colour (nil for default and monochrome).
 * adaptsToUserAccentColor is YES for the default and preferred types (which let
 * the user's accent colour override), NO for fixed and monochrome. The
 * equivalent content tint colour is derived by AppKit from the tint — stage2;
 * here it mirrors baseTintColor.
 */
#import "NSTintConfiguration.h"

typedef NS_ENUM(NSInteger, NSTintConfigurationType) {
    NSTintConfigurationTypeDefault = 0,
    NSTintConfigurationTypeMonochrome = 1,
    NSTintConfigurationTypeFixedColor = 2,
    NSTintConfigurationTypePreferredColor = 3,
};

@implementation NSTintConfiguration {
    NSTintConfigurationType _type;
    id _tintColor;
    BOOL _allowsAccentOverride;
}

+ (NSTintConfiguration *)defaultTintConfiguration
{
    NSTintConfiguration *c = [[self alloc] init];
    c->_type = NSTintConfigurationTypeDefault;
    c->_allowsAccentOverride = YES;
    return c;
}
+ (NSTintConfiguration *)monochromeTintConfiguration
{
    NSTintConfiguration *c = [[self alloc] init];
    c->_type = NSTintConfigurationTypeMonochrome;
    return c;
}
+ (instancetype)tintConfigurationWithFixedColor:(id)color
{
    NSTintConfiguration *c = [[self alloc] init];
    c->_type = NSTintConfigurationTypeFixedColor;
    c->_tintColor = color;
    return c;
}
+ (instancetype)tintConfigurationWithPreferredColor:(id)color
{
    NSTintConfiguration *c = [[self alloc] init];
    c->_type = NSTintConfigurationTypePreferredColor;
    c->_tintColor = color;
    c->_allowsAccentOverride = YES;
    return c;
}

- (id)baseTintColor { return _tintColor; }
- (id)equivalentContentTintColor { return _tintColor; }   /* stage2: real derivation */
- (BOOL)adaptsToUserAccentColor { return _allowsAccentOverride; }

- (id)copyWithZone:(NSZone *)zone
{
    NSTintConfiguration *c = [[NSTintConfiguration alloc] init];
    c->_type = _type; c->_tintColor = _tintColor; c->_allowsAccentOverride = _allowsAccentOverride;
    return c;
}

@end

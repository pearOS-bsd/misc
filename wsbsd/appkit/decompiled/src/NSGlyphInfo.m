/*
 * NSGlyphInfo.m — 1:1 (core). See NSGlyphInfo.h for the interface evidence.
 *
 * Stores the base string plus either a (characterIdentifier, collection) pair
 * or a glyph name. glyphInfoWithCharacterIdentifier:collection:baseString: and
 * glyphInfoWithGlyphName:forFont:baseString: record their inputs directly; the
 * font-based CGGlyph constructors that resolve a glyph through a CTFont are
 * stage2. A CID-based info reports nil glyphName and vice versa.
 */
#import "NSGlyphInfo.h"

@implementation NSGlyphInfo {
    NSString *_baseString;
    NSUInteger _characterIdentifier;
    NSCharacterCollection _characterCollection;
    NSString *_glyphName;
}

+ (NSGlyphInfo *)glyphInfoWithCharacterIdentifier:(NSUInteger)cid
                                       collection:(NSCharacterCollection)collection
                                       baseString:(NSString *)string
{
    if (string.length == 0) return nil;
    NSGlyphInfo *g = [[NSGlyphInfo alloc] init];
    g->_baseString = [string copy];
    g->_characterIdentifier = cid;
    g->_characterCollection = collection;
    return g;
}

+ (NSGlyphInfo *)glyphInfoWithGlyphName:(NSString *)glyphName
                                forFont:(id)font
                             baseString:(NSString *)string
{
    if (glyphName.length == 0 || string.length == 0) return nil;
    NSGlyphInfo *g = [[NSGlyphInfo alloc] init];
    g->_baseString = [string copy];
    g->_glyphName = [glyphName copy];
    g->_characterCollection = NSIdentityMappingCharacterCollection;
    return g;
}

- (NSString *)baseString { return _baseString; }
- (NSUInteger)characterIdentifier { return _characterIdentifier; }
- (NSCharacterCollection)characterCollection { return _characterCollection; }
- (NSString *)glyphName { return _glyphName; }

- (id)copyWithZone:(NSZone *)zone
{
    NSGlyphInfo *c = [[NSGlyphInfo alloc] init];
    c->_baseString = [_baseString copy];
    c->_characterIdentifier = _characterIdentifier;
    c->_characterCollection = _characterCollection;
    c->_glyphName = [_glyphName copy];
    return c;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSGlyphInfo class]]) return NO;
    NSGlyphInfo *o = object;
    return _characterIdentifier == o->_characterIdentifier &&
           _characterCollection == o->_characterCollection &&
           ((_glyphName == o->_glyphName) || [_glyphName isEqualToString:o->_glyphName]) &&
           [_baseString isEqualToString:o->_baseString];
}

- (NSUInteger)hash { return _characterIdentifier ^ _baseString.hash; }

@end

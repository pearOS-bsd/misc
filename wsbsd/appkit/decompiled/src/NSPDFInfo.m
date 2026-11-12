/*
 * NSPDFInfo.m — behavioral-1:1 core. See the header.
 */

#import "NSPDFInfo.h"

@implementation NSPDFInfo {
    NSURL *_URL;
    NSArray<NSString *> *_tagNames;
    NSPaperOrientation _orientation;
    CGSize _paperSize;
    NSMutableDictionary *_attributes;
    BOOL _fileExtensionHidden;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tagNames = @[];                     /* measured */
        _orientation = NSPaperOrientationPortrait;
        _paperSize = CGSizeMake(595.0, 842.0); /* A4 in points, measured */
        _fileExtensionHidden = YES;          /* measured */
        _attributes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURL *)URL { return _URL; }
- (void)setURL:(NSURL *)u { _URL = [u copy]; }
- (BOOL)isFileExtensionHidden { return _fileExtensionHidden; }
- (void)setFileExtensionHidden:(BOOL)v { _fileExtensionHidden = v; }
- (NSArray<NSString *> *)tagNames { return _tagNames; }
- (void)setTagNames:(NSArray<NSString *> *)t { _tagNames = [t copy] ?: @[]; }
- (NSPaperOrientation)orientation { return _orientation; }
- (void)setOrientation:(NSPaperOrientation)o { _orientation = o; }
- (CGSize)paperSize { return _paperSize; }
- (void)setPaperSize:(CGSize)s { _paperSize = s; }
- (NSMutableDictionary *)attributes { return _attributes; }

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSPDFInfo *c = [[[self class] alloc] init];
    c->_URL = [_URL copy];
    c->_tagNames = [_tagNames copy] ?: @[];
    c->_orientation = _orientation;
    c->_paperSize = _paperSize;
    c->_fileExtensionHidden = _fileExtensionHidden;
    c->_attributes = [_attributes mutableCopy] ?: [NSMutableDictionary dictionary]; /* independent */
    return c;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_URL forKey:@"URL"];
    [coder encodeObject:_tagNames forKey:@"tagNames"];
    [coder encodeInteger:_orientation forKey:@"orientation"];
    [coder encodeDouble:_paperSize.width forKey:@"paperSize.width"];
    [coder encodeDouble:_paperSize.height forKey:@"paperSize.height"];
    [coder encodeBool:_fileExtensionHidden forKey:@"fileExtensionHidden"];
    [coder encodeObject:_attributes forKey:@"attributes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _URL = [coder decodeObjectForKey:@"URL"];
        _tagNames = [coder decodeObjectForKey:@"tagNames"] ?: @[];
        _orientation = [coder decodeIntegerForKey:@"orientation"];
        _paperSize = CGSizeMake([coder decodeDoubleForKey:@"paperSize.width"],
                                [coder decodeDoubleForKey:@"paperSize.height"]);
        _fileExtensionHidden = [coder decodeBoolForKey:@"fileExtensionHidden"];
        NSDictionary *a = [coder decodeObjectForKey:@"attributes"];
        _attributes = a ? [a mutableCopy] : [NSMutableDictionary dictionary];
    }
    return self;
}

@end

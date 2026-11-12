/*
 * NSPrinter.m — behavioral-1:1 core. See the header.
 */

#import "NSPrinter.h"

@implementation NSPrinter {
    NSString *_name;
    NSString *_type;
    NSInteger _languageLevel;
    NSDictionary *_deviceDescription;
}

+ (NSArray<NSString *> *)printerNames { return @[]; }   /* CUPS registry = stage2 */
+ (NSArray<NSString *> *)printerTypes { return @[]; }   /* PPD catalogue = stage2 */

+ (NSPrinter *)printerWithName:(NSString *)name
{
    if (name.length == 0) return nil;
    NSPrinter *p = [[self alloc] init];
    p->_name = [name copy];
    p->_type = [name copy];
    p->_languageLevel = 2;   /* PostScript Level 2 — real value from the PPD (stage2) */
    p->_deviceDescription = @{};
    return p;
}

+ (NSPrinter *)printerWithType:(NSString *)type
{
    if (type.length == 0) return nil;
    NSPrinter *p = [[self alloc] init];
    p->_name = [type copy];
    p->_type = [type copy];
    p->_languageLevel = 2;
    p->_deviceDescription = @{};
    return p;
}

- (NSString *)name { return _name; }
- (NSString *)type { return _type; }
- (NSInteger)languageLevel { return _languageLevel; }
- (NSDictionary *)deviceDescription { return _deviceDescription ?: @{}; }

- (CGSize)pageSizeForPaper:(NSString *)paperName
{
    /* TODO(stage2): look the paper up in the PPD. US Letter as a safe fallback. */
    if ([paperName isEqualToString:@"A4"]) return CGSizeMake(595, 842);
    return CGSizeMake(612, 792);
}

#pragma mark - NSCopying / NSSecureCoding

+ (BOOL)supportsSecureCoding { return YES; }

- (id)copyWithZone:(NSZone *)zone
{
    NSPrinter *c = [[[self class] alloc] init];
    c->_name = [_name copy];
    c->_type = [_type copy];
    c->_languageLevel = _languageLevel;
    c->_deviceDescription = [_deviceDescription copy];
    return c;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_type forKey:@"type"];
    [coder encodeInteger:_languageLevel forKey:@"languageLevel"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [coder decodeObjectForKey:@"name"];
        _type = [coder decodeObjectForKey:@"type"];
        _languageLevel = [coder decodeIntegerForKey:@"languageLevel"];
        _deviceDescription = @{};
    }
    return self;
}

@end

/*
 * NSTextList.m — 1:1 (core). See NSTextList.h for the interface evidence.
 *
 * markerForItemNumber: finds the "{token}" placeholder in the marker format and
 * replaces it with the item counter rendered per the token, keeping any prefix/
 * suffix characters. Tokens:
 *   {decimal}                     -> 1, 2, 3 …                 (ordered)
 *   {lower-roman}/{upper-roman}   -> i/ii/… or I/II/…          (ordered)
 *   {lower-alpha}/{lower-latin}   -> a, b, …, z, aa, …         (ordered)
 *   {upper-alpha}/{upper-latin}   -> A, B, …                   (ordered)
 *   {disc} {circle} {square} {hyphen} {check} {diamond} {box}  (unordered glyphs)
 * isOrdered is true iff the token is a numeric/alpha/roman counter.
 */
#import "NSTextList.h"

@implementation NSTextList {
    NSString *_markerFormat;
    NSTextListOptions _listFlags;
    NSInteger _startIndex;
}

- (instancetype)initWithMarkerFormat:(NSString *)format options:(NSUInteger)mask
{
    self = [super init];
    if (self) {
        _markerFormat = [format copy];
        _listFlags = (NSTextListOptions)mask;
        _startIndex = 1;
    }
    return self;
}

- (NSString *)markerFormat { return _markerFormat; }
- (NSTextListOptions)listOptions { return _listFlags; }
- (NSInteger)startingItemNumber { return _startIndex; }
- (void)setStartingItemNumber:(NSInteger)n { _startIndex = n; }

static NSString *NSTextListToken(NSString *fmt)
{
    NSRange open = [fmt rangeOfString:@"{"];
    NSRange close = [fmt rangeOfString:@"}"];
    if (open.location == NSNotFound || close.location == NSNotFound || close.location < open.location)
        return nil;
    NSRange inner = NSMakeRange(open.location + 1, close.location - open.location - 1);
    return [fmt substringWithRange:inner];
}

- (BOOL)isOrdered
{
    NSString *tok = NSTextListToken(_markerFormat);
    if (!tok) return NO;
    static NSSet *ordered;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ordered = [NSSet setWithArray:@[ @"decimal", @"lower-roman", @"upper-roman",
            @"lower-alpha", @"upper-alpha", @"lower-latin", @"upper-latin",
            @"lower-hexadecimal", @"upper-hexadecimal", @"octal" ]];
    });
    return [ordered containsObject:tok];
}

static NSString *NSTextListRoman(NSInteger n, BOOL upper)
{
    if (n <= 0) return @"";
    const char *syms[] = {"m","cm","d","cd","c","xc","l","xl","x","ix","v","iv","i"};
    const int vals[] = {1000,900,500,400,100,90,50,40,10,9,5,4,1};
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < 13 && n > 0; i++) {
        while (n >= vals[i]) { [s appendFormat:@"%s", syms[i]]; n -= vals[i]; }
    }
    return upper ? s.uppercaseString : s;
}

static NSString *NSTextListAlpha(NSInteger n, BOOL upper)
{
    if (n <= 0) return @"";
    NSMutableString *s = [NSMutableString string];
    while (n > 0) {
        n--;
        unichar c = (unichar)((upper ? 'A' : 'a') + (n % 26));
        [s insertString:[NSString stringWithCharacters:&c length:1] atIndex:0];
        n /= 26;
    }
    return s;
}

- (NSString *)markerForItemNumber:(NSInteger)itemNumber
{
    NSString *tok = NSTextListToken(_markerFormat);
    if (!tok) return _markerFormat; /* literal marker, no placeholder */

    NSString *rendered;
    if ([tok isEqualToString:@"decimal"])            rendered = [NSString stringWithFormat:@"%ld", (long)itemNumber];
    else if ([tok isEqualToString:@"lower-roman"])   rendered = NSTextListRoman(itemNumber, NO);
    else if ([tok isEqualToString:@"upper-roman"])   rendered = NSTextListRoman(itemNumber, YES);
    else if ([tok isEqualToString:@"lower-alpha"] || [tok isEqualToString:@"lower-latin"]) rendered = NSTextListAlpha(itemNumber, NO);
    else if ([tok isEqualToString:@"upper-alpha"] || [tok isEqualToString:@"upper-latin"]) rendered = NSTextListAlpha(itemNumber, YES);
    else if ([tok isEqualToString:@"disc"])          rendered = @"•"; /* • */
    else if ([tok isEqualToString:@"circle"])        rendered = @"◦"; /* ◦ */
    else if ([tok isEqualToString:@"square"])        rendered = @"▪"; /* ▪ */
    else if ([tok isEqualToString:@"hyphen"])        rendered = @"-";
    else if ([tok isEqualToString:@"check"])         rendered = @"✓"; /* ✓ */
    else if ([tok isEqualToString:@"diamond"])       rendered = @"◆"; /* ◆ */
    else if ([tok isEqualToString:@"box"])           rendered = @"□"; /* □ */
    else                                             rendered = tok;

    /* keep any prefix/suffix around the {token} */
    NSString *placeholder = [NSString stringWithFormat:@"{%@}", tok];
    return [_markerFormat stringByReplacingOccurrencesOfString:placeholder withString:rendered];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSTextList *c = [[NSTextList alloc] initWithMarkerFormat:_markerFormat options:_listFlags];
    c->_startIndex = _startIndex;
    return c;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSTextList class]]) return NO;
    NSTextList *o = object;
    return [o->_markerFormat isEqualToString:_markerFormat] &&
           o->_listFlags == _listFlags && o->_startIndex == _startIndex;
}

- (NSUInteger)hash { return _markerFormat.hash ^ _listFlags; }

@end

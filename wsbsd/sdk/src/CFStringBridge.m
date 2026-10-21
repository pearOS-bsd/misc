/* gnustep-corebase's NSCFString (the class of every CFString) hands the character set of rangeOfCharacterFromSet:... to CFStringFindCharacterFromSet as if it were a CFCharacterSet; the sets of
 * gnustep-base are not, and the call dereferences a bad pointer inside ICU (any NSString method built on it, lastPathComponent among them, crashes on a CFString). The methods are replaced here by
 * ones that run the search on a plain NSString copy of the text. */
#import <Foundation/Foundation.h>

@interface NSCFString : NSString
@end
@implementation NSCFString (WsbsdCharacterSets)
- (NSString *)wsbsdNative
{
	NSUInteger n = [self length]; unichar *b = malloc((n + 1) * sizeof(unichar)); [self getCharacters: b range: NSMakeRange(0, n)];
	NSString *s = [NSString stringWithCharacters: b length: n]; free(b); return s;
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)mask range:(NSRange)range
{
	return [[self wsbsdNative] rangeOfCharacterFromSet: set options: mask range: range];
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)mask { return [self rangeOfCharacterFromSet: set options: mask range: NSMakeRange(0, [self length])]; }
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set { return [self rangeOfCharacterFromSet: set options: 0 range: NSMakeRange(0, [self length])]; }
@end

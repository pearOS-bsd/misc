/* Classes that compiled nibs of the Mac name and GNUstep's keyed unarchiver does not know: NSLocalizableString (a string with its key and the development value), more on demand. */
#import <AppKit/AppKit.h>

@interface NSLocalizableString : NSString @end
@implementation NSLocalizableString
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c
{
	NSUInteger n = 0; const uint8_t *b = [c decodeBytesForKey: @"NS.bytes" returnedLength: &n]; NSString *s = b ? [[NSString alloc] initWithBytes: b length: n encoding: NSUTF8StringEncoding] : nil;
	if (!s) s = [c decodeObjectForKey: @"NSDev"]; return (id)[s copy] ?: (id)@"";
}
@end

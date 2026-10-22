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

@interface NSCalendar (WsbsdRelativeDays) @end
@implementation NSCalendar (WsbsdRelativeDays)
- (BOOL)_isDate:(NSDate *)d dayOffset:(int)off { NSDateComponents *c = [[NSDateComponents alloc] init]; [c setDay: off]; NSDate *t = [self dateByAddingComponents: c toDate: [NSDate date] options: 0]; NSUInteger u = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit; NSDateComponents *a = [self components: u fromDate: d], *b = [self components: u fromDate: t]; return [a year] == [b year] && [a month] == [b month] && [a day] == [b day]; }
- (BOOL)isDateInToday:(NSDate *)d { return [self _isDate: d dayOffset: 0]; }
- (BOOL)isDateInYesterday:(NSDate *)d { return [self _isDate: d dayOffset: -1]; }
- (BOOL)isDateInTomorrow:(NSDate *)d { return [self _isDate: d dayOffset: 1]; }
@end
/* the order of the Finder: numbers by value, case and accents ignored */
@interface NSString (WsbsdLocalizedStandard) @end
@implementation NSString (WsbsdLocalizedStandard)
- (NSComparisonResult)localizedStandardCompare:(NSString *)other
{
	return [self compare: other options: NSNumericSearch | NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch range: NSMakeRange(0, [self length]) locale: [NSLocale currentLocale]];
}
- (BOOL)localizedStandardContainsString:(NSString *)s { return [self rangeOfString: s options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound; }
@end

/* an application started as Name.app/Contents/MacOS/Name (the layout of the Mac) has Name.app as its main bundle (GNUstep would look for Resources beside the executable) */
#import <objc/runtime.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
static IMP origMainBundle; static NSBundle *gMainBundle; static BOOL gMainBundleChecked;
static id NewMainBundle(id self, SEL _cmd)
{
	if (!gMainBundleChecked) {
		gMainBundleChecked = YES; char buf[4096]; size_t len = sizeof buf; int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, -1 }; ssize_t n = sysctl(mib, 4, buf, &len, NULL, 0) == 0 ? (ssize_t)len - 1 : -1;
		if (n > 0) { buf[n] = 0; NSString *p = @(buf); NSRange r = [p rangeOfString: @".app/Contents/MacOS/"]; if (r.location != NSNotFound) { NSString *app = [p substringToIndex: NSMaxRange(r) - [@"/Contents/MacOS/" length]]; gMainBundle = [NSBundle bundleWithPath: app]; } }
	}
	return gMainBundle ?: ((id (*)(id, SEL))origMainBundle)(self, _cmd);
}
@interface WsbsdMainBundle : NSObject @end
@implementation WsbsdMainBundle
+ (void)load { Method m = class_getClassMethod(objc_getClass("NSBundle"), @selector(mainBundle)); if (m) { origMainBundle = method_getImplementation(m); method_setImplementation(m, (IMP)NewMainBundle); } }
@end

/* Rename of several items at once (File > Rename N Items…): Replace Text, Add Text or Format (Name and Index, Name and Counter, Name and Date), as the Finder offers them. */
#import "TFinderViews.h"
#import <objc/runtime.h>

/* the new names for the paths; p: mode 0 replace / 1 add / 2 format, find, replace, text, after (BOOL), format 0 index / 1 counter / 2 date, custom, start */
NSArray *TFBulkRenamedNames(NSArray *paths, NSDictionary *p)
{
	NSInteger mode = [p[@"mode"] integerValue]; NSMutableArray *out = [NSMutableArray array]; long long n = [p[@"start"] ?: @1 longLongValue]; BOOL after = [p[@"after"] boolValue];
	for (NSString *path in paths) {
		NSString *name = [path lastPathComponent], *ext = [name pathExtension], *base = [ext length] ? [name stringByDeletingPathExtension] : name; NSString *res = name;
		if (mode == 0) { NSString *f = p[@"find"] ?: @""; if ([f length]) res = [name stringByReplacingOccurrencesOfString: f withString: p[@"replace"] ?: @"" options: NSLiteralSearch range: NSMakeRange(0, [name length])]; }
		else {
			NSString *mid = nil;
			if (mode == 1) { mid = p[@"text"] ?: @""; res = after ? [base stringByAppendingString: mid] : [mid stringByAppendingString: base]; }
			else {
				NSInteger kind = [p[@"format"] integerValue]; NSString *label = [p[@"custom"] length] ? p[@"custom"] : base;
				if (kind == 0) mid = [NSString stringWithFormat: @"%lld", n]; else if (kind == 1) mid = [NSString stringWithFormat: @"%04lld", n];
				else { NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"yyyy-MM-dd 'at' HH.mm.ss"]; mid = [df stringFromDate: [[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL][NSFileModificationDate] ?: [NSDate date]]; }
				res = after ? [NSString stringWithFormat: @"%@ %@", label, mid] : [NSString stringWithFormat: @"%@ %@", mid, label];
			}
			if ([ext length]) res = [res stringByAppendingPathExtension: ext];
		}
		n++; [out addObject: res];
	}
	return out;
}


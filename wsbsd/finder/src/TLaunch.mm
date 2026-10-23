/* The applications that can open a file (Open With): the .app bundles of /Applications, /System/Applications, /Applications/Utilities and ~/Applications whose Info.plist lists the file's extension or a type the file's type conforms to
 * (CFBundleDocumentTypes: CFBundleTypeExtensions, LSItemContentTypes). The scan is kept for a minute. */
#import "TFinderViews.h"
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSArray *AppIndex(void)
{
	static NSArray *idx; static time_t at; time_t now = time(NULL); if (idx && now - at < 60) return idx; at = now; NSMutableArray *out = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *dir in @[ @"/Applications", @"/System/Applications", @"/Applications/Utilities", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"], @"/System/Library/CoreServices" ]) for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
		if (![[n pathExtension] isEqual: @"app"]) continue; NSString *p = [dir stringByAppendingPathComponent: n]; NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [p stringByAppendingPathComponent: @"Contents/Info.plist"]] ?: [NSDictionary dictionaryWithContentsOfFile: [p stringByAppendingPathComponent: @"Info.plist"]]; if (!info) continue;
		NSMutableSet *exts = [NSMutableSet set], *utis = [NSMutableSet set]; for (NSDictionary *d in info[@"CFBundleDocumentTypes"]) { for (NSString *e in d[@"CFBundleTypeExtensions"] ?: @[]) [exts addObject: [e lowercaseString]]; for (NSString *u in d[@"LSItemContentTypes"] ?: @[]) [utis addObject: u]; }
		[out addObject: @{ @"path": p, @"name": info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: [n stringByDeletingPathExtension], @"exts": exts, @"utis": utis, @"id": info[@"CFBundleIdentifier"] ?: @"" }];
	}
	idx = out; return idx;
}
NSArray *TFAppsForFile(NSString *path)
{
	NSString *ext = [[path pathExtension] lowercaseString]; NSString *uti = [ext length] ? (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL) : nil; NSMutableArray *res = [NSMutableArray array];
	for (NSDictionary *a in AppIndex()) { BOOL ok = [a[@"exts"] containsObject: ext] || [a[@"exts"] containsObject: @"*"]; if (!ok && uti) for (NSString *u in a[@"utis"]) if (UTTypeConformsTo((__bridge CFStringRef)uti, (__bridge CFStringRef)u)) { ok = YES; break; } if (ok) [res addObject: a]; }
	[res sortUsingComparator: ^NSComparisonResult(NSDictionary *x, NSDictionary *y) { return [x[@"name"] tfNameCompare: y[@"name"]]; }]; return res;
}

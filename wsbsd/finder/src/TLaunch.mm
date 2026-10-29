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
	[res sortUsingComparator: ^NSComparisonResult(NSDictionary *x, NSDictionary *y) { return [x[@"name"] tfNameCompare: y[@"name"]]; }];
	/* the application chosen for this file, else for all files of its extension, is the default and comes first */
	NSString *want = TFPref(@"OpenWithFile", @{})[path] ?: TFPref(@"OpenWith", @{})[ext]; for (NSUInteger i = 0; want && i < [res count]; i++) if ([res[i][@"path"] isEqual: want]) { NSDictionary *a = res[i]; [res removeObjectAtIndex: i]; [res insertObject: a atIndex: 0]; break; }
	return res;
}
/* Open with of Get Info: the application for this file only, or for every file of the extension (Change All…) */
void TFSetOpenWith(NSString *path, NSString *app, BOOL all)
{
	NSString *key = all ? @"OpenWith" : @"OpenWithFile", *k = all ? [[path pathExtension] lowercaseString] : path; if (![k length]) return;
	NSMutableDictionary *d = [TFPref(key, @{}) mutableCopy]; d[k] = app; TFSetPref(key, d);
}
/* a double click: the application chosen in Get Info when there is one, else what the system opens it with */
void TFOpenPath(NSString *path)
{
	NSString *ext = [[path pathExtension] lowercaseString]; NSString *app = TFPref(@"OpenWithFile", @{})[path] ?: ([ext length] ? TFPref(@"OpenWith", @{})[ext] : nil);
	if (app && [[NSFileManager defaultManager] fileExistsAtPath: app]) { [[NSWorkspace sharedWorkspace] openFile: path withApplication: app]; return; }
	/* text documents open in TextEdit, as on the Mac (the image carries it as /usr/local/bin/TextEdit-gnustep, not as a bundle the application scan finds) */
	static NSSet *text; if (!text) text = [NSSet setWithObjects: @"txt", @"text", @"md", @"markdown", @"rtf", @"log", @"json", @"xml", @"csv", @"tsv", @"sh", @"zsh", @"conf", @"cfg", @"ini", @"yaml", @"yml", @"c", @"h", @"m", @"mm", @"py", @"js", @"css", @"html", @"htm", nil];
	NSString *te = nil; for (NSString *c in @[ @"/usr/local/bin/TextEdit-gnustep", @"/System/Applications/TextEdit.app/Contents/MacOS/TextEdit" ]) if ([[NSFileManager defaultManager] isExecutableFileAtPath: c]) { te = c; break; }
	if ([text containsObject: ext] && te) { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: te]; [t setArguments: @[ @"-NSOpen", path ]]; @try { [t launch]; return; } @catch (NSException *e) {} }
	[[NSWorkspace sharedWorkspace] openFile: path];
}

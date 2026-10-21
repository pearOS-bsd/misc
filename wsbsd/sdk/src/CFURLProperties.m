/* CFURLCopyResourcePropertyForKey and friends for file URLs, answered from stat(2) and statfs(2); gnustep-corebase has stubs that fail. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/stat.h>
#include <sys/mount.h>

static id YN(BOOL x) { return x ? (__bridge id)kCFBooleanTrue : (__bridge id)kCFBooleanFalse; }          /* the answers are CFBooleans: callers compare them with kCFBooleanTrue */
static CFTypeRef Property(NSString *path, struct stat *st, BOOL ok, CFStringRef key)
{
	NSString *k = (__bridge NSString *)key; id v = nil; NSString *name = [path lastPathComponent];
	if ([k isEqual: @"NSURLNameKey"] || [k isEqual: @"NSURLLocalizedNameKey"]) v = name;
	else if ([k isEqual: @"NSURLIsHiddenKey"]) v = YN([name hasPrefix: @"."]);
	else if ([k isEqual: @"NSURLIsAliasFileKey"]) v = YN(NO);                                                         /* there are no Finder aliases */
	else if ([k isEqual: @"NSURLIsPackageKey"]) v = YN(ok && S_ISDIR(st->st_mode) && ([[path pathExtension] isEqual: @"app"] || [[path pathExtension] isEqual: @"bundle"] || [[path pathExtension] isEqual: @"framework"]));
	else if ([k isEqual: @"NSURLIsVolumeKey"]) { struct statfs fs; v = YN(statfs([path UTF8String], &fs) == 0 && [path isEqual: [NSString stringWithUTF8String: fs.f_mntonname]]); }
	else if ([k hasPrefix: @"NSURLVolume"]) {
		struct statfs fs; if (statfs([path UTF8String], &fs) != 0) return NULL; NSString *t = [NSString stringWithUTF8String: fs.f_fstypename];
		if ([k isEqual: @"NSURLVolumeIsLocalKey"]) v = YN(![@[ @"nfs", @"smbfs", @"fusefs", @"webdav", @"cifs" ] containsObject: t]);
		else if ([k isEqual: @"NSURLVolumeIsReadOnlyKey"]) v = YN((fs.f_flags & MNT_RDONLY) != 0);
		else if ([k isEqual: @"NSURLVolumeNameKey"] || [k isEqual: @"NSURLVolumeLocalizedNameKey"]) v = [[NSString stringWithUTF8String: fs.f_mntonname] lastPathComponent];
		else if ([k isEqual: @"NSURLVolumeTotalCapacityKey"]) v = @((long long)fs.f_blocks * fs.f_bsize);
		else if ([k isEqual: @"NSURLVolumeAvailableCapacityKey"]) v = @((long long)fs.f_bavail * fs.f_bsize);
		else if ([k isEqual: @"NSURLVolumeSupportsCaseSensitiveNamesKey"]) v = YN(YES);
		else if ([k isEqual: @"NSURLVolumeSupportsSymbolicLinksKey"] || [k isEqual: @"NSURLVolumeSupportsHardLinksKey"]) v = YN(YES);
		else return NULL;
	}
	else if (!ok) return NULL;
	else if ([k isEqual: @"NSURLIsDirectoryKey"]) v = YN(S_ISDIR(st->st_mode));
	else if ([k isEqual: @"NSURLIsRegularFileKey"]) v = YN(S_ISREG(st->st_mode));
	else if ([k isEqual: @"NSURLIsSymbolicLinkKey"]) { struct stat l; v = YN(lstat([path UTF8String], &l) == 0 && S_ISLNK(l.st_mode)); }
	else if ([k isEqual: @"NSURLIsReadableKey"]) v = YN(access([path UTF8String], R_OK) == 0);
	else if ([k isEqual: @"NSURLIsWritableKey"]) v = YN(access([path UTF8String], W_OK) == 0);
	else if ([k isEqual: @"NSURLIsExecutableKey"]) v = YN(access([path UTF8String], X_OK) == 0);
	else if ([k isEqual: @"NSURLFileSizeKey"] || [k isEqual: @"NSURLTotalFileSizeKey"]) v = @((long long)st->st_size);
	else if ([k isEqual: @"NSURLFileAllocatedSizeKey"] || [k isEqual: @"NSURLTotalFileAllocatedSizeKey"]) v = @((long long)st->st_blocks * 512);
	else if ([k isEqual: @"NSURLLinkCountKey"]) v = @((long long)st->st_nlink);
	else if ([k isEqual: @"NSURLContentModificationDateKey"] || [k isEqual: @"NSURLAttributeModificationDateKey"]) v = [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st->st_mtime];
	else if ([k isEqual: @"NSURLContentAccessDateKey"]) v = [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st->st_atime];
	else if ([k isEqual: @"NSURLCreationDateKey"]) v = [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)st->st_birthtime];
	else if ([k isEqual: @"NSURLParentDirectoryURLKey"]) v = [NSURL fileURLWithPath: [path stringByDeletingLastPathComponent] isDirectory: YES];
	else return NULL;
	return v ? CFBridgingRetain(v) : NULL;
}
/* a CFURL of gnustep-corebase is not an NSURL: the path comes through the CF calls (nil for URLs that are not files) */
static NSString *FilePath(CFURLRef url)
{
	if (!url) return nil; CFStringRef scheme = CFURLCopyScheme(url); BOOL file = !scheme || CFStringCompare(scheme, CFSTR("file"), 0) == kCFCompareEqualTo;           /* a file system path URL may carry no scheme */ if (scheme) CFRelease(scheme); if (!file) return nil;
	CFStringRef p = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle); if (!p) return nil; char buf[4096]; BOOL ok = CFStringGetCString(p, buf, sizeof buf, kCFStringEncodingUTF8); CFRelease(p); return ok ? [NSString stringWithUTF8String: buf] : nil;
}
Boolean CFURLCopyResourcePropertyForKey(CFURLRef url, CFStringRef key, void *out, CFErrorRef *error)
{
	if (error) *error = NULL; NSString *p = FilePath(url); if (!p || !out) return false;
	struct stat st; BOOL ok = stat([p UTF8String], &st) == 0; CFTypeRef v = Property(p, &st, ok, key);
	*(CFTypeRef *)out = v; return v != NULL;
}
CFDictionaryRef CFURLCopyResourcePropertiesForKeys(CFURLRef url, CFArrayRef keys, CFErrorRef *error)
{
	if (error) *error = NULL; NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSString *p = FilePath(url); if (!p) return NULL;
	struct stat st; BOOL ok = stat([p UTF8String], &st) == 0;
	for (NSString *k in (__bridge NSArray *)keys) { CFTypeRef v = Property(p, &st, ok, (__bridge CFStringRef)k); if (v) d[k] = CFBridgingRelease(v); }
	return (CFDictionaryRef)CFBridgingRetain(d);
}
void CFURLClearResourcePropertyCacheForKey(CFURLRef url, CFStringRef key) { (void)url; (void)key; }

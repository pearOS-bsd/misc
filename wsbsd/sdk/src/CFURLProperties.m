/* CFURLCopyResourcePropertyForKey and friends for file URLs, answered from stat(2) and statfs(2); gnustep-corebase has stubs that fail. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/stat.h>
#include <sys/mount.h>

static CFTypeRef Property(NSString *path, struct stat *st, BOOL ok, CFStringRef key)
{
	NSString *k = (__bridge NSString *)key; id v = nil; NSString *name = [path lastPathComponent];
	if ([k isEqual: @"NSURLNameKey"] || [k isEqual: @"NSURLLocalizedNameKey"]) v = name;
	else if ([k isEqual: @"NSURLIsHiddenKey"]) v = @([name hasPrefix: @"."]);
	else if ([k isEqual: @"NSURLIsAliasFileKey"]) v = @NO;                                                         /* there are no Finder aliases */
	else if ([k isEqual: @"NSURLIsPackageKey"]) v = @(ok && S_ISDIR(st->st_mode) && ([[path pathExtension] isEqual: @"app"] || [[path pathExtension] isEqual: @"bundle"] || [[path pathExtension] isEqual: @"framework"]));
	else if ([k isEqual: @"NSURLIsVolumeKey"]) { struct statfs fs; v = @(statfs([path fileSystemRepresentation], &fs) == 0 && [path isEqual: [NSString stringWithUTF8String: fs.f_mntonname]]); }
	else if ([k hasPrefix: @"NSURLVolume"]) {
		struct statfs fs; if (statfs([path fileSystemRepresentation], &fs) != 0) return NULL; NSString *t = [NSString stringWithUTF8String: fs.f_fstypename];
		if ([k isEqual: @"NSURLVolumeIsLocalKey"]) v = @(![@[ @"nfs", @"smbfs", @"fusefs", @"webdav", @"cifs" ] containsObject: t]);
		else if ([k isEqual: @"NSURLVolumeIsReadOnlyKey"]) v = @((fs.f_flags & MNT_RDONLY) != 0);
		else if ([k isEqual: @"NSURLVolumeNameKey"] || [k isEqual: @"NSURLVolumeLocalizedNameKey"]) v = [[NSString stringWithUTF8String: fs.f_mntonname] lastPathComponent];
		else if ([k isEqual: @"NSURLVolumeTotalCapacityKey"]) v = @((long long)fs.f_blocks * fs.f_bsize);
		else if ([k isEqual: @"NSURLVolumeAvailableCapacityKey"]) v = @((long long)fs.f_bavail * fs.f_bsize);
		else if ([k isEqual: @"NSURLVolumeSupportsCaseSensitiveNamesKey"]) v = @YES;
		else if ([k isEqual: @"NSURLVolumeSupportsSymbolicLinksKey"] || [k isEqual: @"NSURLVolumeSupportsHardLinksKey"]) v = @YES;
		else return NULL;
	}
	else if (!ok) return NULL;
	else if ([k isEqual: @"NSURLIsDirectoryKey"]) v = @(S_ISDIR(st->st_mode));
	else if ([k isEqual: @"NSURLIsRegularFileKey"]) v = @(S_ISREG(st->st_mode));
	else if ([k isEqual: @"NSURLIsSymbolicLinkKey"]) { struct stat l; v = @(lstat([path fileSystemRepresentation], &l) == 0 && S_ISLNK(l.st_mode)); }
	else if ([k isEqual: @"NSURLIsReadableKey"]) v = @(access([path fileSystemRepresentation], R_OK) == 0);
	else if ([k isEqual: @"NSURLIsWritableKey"]) v = @(access([path fileSystemRepresentation], W_OK) == 0);
	else if ([k isEqual: @"NSURLIsExecutableKey"]) v = @(access([path fileSystemRepresentation], X_OK) == 0);
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
Boolean CFURLCopyResourcePropertyForKey(CFURLRef url, CFStringRef key, void *out, CFErrorRef *error)
{
	if (error) *error = NULL; NSURL *u = (__bridge NSURL *)url; if (![u isFileURL] || !out) return false;
	NSString *p = [u path]; struct stat st; BOOL ok = stat([p fileSystemRepresentation], &st) == 0; CFTypeRef v = Property(p, &st, ok, key);
	*(CFTypeRef *)out = v; return v != NULL;
}
CFDictionaryRef CFURLCopyResourcePropertiesForKeys(CFURLRef url, CFArrayRef keys, CFErrorRef *error)
{
	if (error) *error = NULL; NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSURL *u = (__bridge NSURL *)url; if (![u isFileURL]) return NULL;
	NSString *p = [u path]; struct stat st; BOOL ok = stat([p fileSystemRepresentation], &st) == 0;
	for (NSString *k in (__bridge NSArray *)keys) { CFTypeRef v = Property(p, &st, ok, (__bridge CFStringRef)k); if (v) d[k] = CFBridgingRelease(v); }
	return (CFDictionaryRef)CFBridgingRetain(d);
}
void CFURLClearResourcePropertyCacheForKey(CFURLRef url, CFStringRef key) { (void)url; (void)key; }

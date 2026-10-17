/* Carbon File Manager over POSIX: FSRef is the absolute path, an FSIterator reads a directory with readdir and fills FSCatalogInfo from lstat. */
#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <sys/param.h>

#define MAC_EPOCH_OFFSET 2082844800ULL      /* 1904 to 1970 */
struct OpaqueFSIterator { DIR *dir; char path[PATH_MAX]; };

static void put_path(FSRef *ref, const char *p) { memset(ref->hidden, 0, sizeof ref->hidden); strncpy((char *)ref->hidden, p, sizeof ref->hidden - 1); }
static const char *ref_path(const FSRef *ref) { return (const char *)ref->hidden; }
static void utc(UTCDateTime *d, time_t t, long nsec)
{
	uint64_t s = (uint64_t)t + MAC_EPOCH_OFFSET;
	d->highSeconds = (UInt16)(s >> 32); d->lowSeconds = (UInt32)s; d->fraction = (UInt16)(((uint64_t)nsec * 65536) / 1000000000ULL);
}
static void fill_info(const struct stat *st, FSCatalogInfoBitmap which, FSCatalogInfo *ci)
{
	memset(ci, 0, sizeof *ci);
	if (which & kFSCatInfoNodeFlags) {
		ci->nodeFlags = S_ISDIR(st->st_mode) ? kFSNodeIsDirectoryMask : 0;
		if (!S_ISDIR(st->st_mode) && st->st_nlink > 1) ci->nodeFlags |= kFSNodeHardLinkMask;
	}
	ci->nodeID = (UInt32)st->st_ino; ci->volume = (FSVolumeRefNum)st->st_dev;
	utc(&ci->createDate, st->st_birthtim.tv_sec, st->st_birthtim.tv_nsec);
	utc(&ci->contentModDate, st->st_mtim.tv_sec, st->st_mtim.tv_nsec);
	utc(&ci->attributeModDate, st->st_ctim.tv_sec, st->st_ctim.tv_nsec);
	utc(&ci->accessDate, st->st_atim.tv_sec, st->st_atim.tv_nsec);
	if (!S_ISDIR(st->st_mode)) { ci->dataLogicalSize = (UInt64)st->st_size; ci->dataPhysicalSize = (UInt64)st->st_blocks * 512; }
	ci->permissions[0] = st->st_uid; ci->permissions[1] = st->st_gid; ci->permissions[2] = st->st_mode;
}
static void name_from_utf8(HFSUniStr255 *n, const char *s)
{
	CFStringRef cf = CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
	CFIndex len = cf ? CFStringGetLength(cf) : 0;
	if (len > 255) len = 255;
	if (cf) { CFStringGetCharacters(cf, CFRangeMake(0, len), n->unicode); CFRelease(cf); }
	n->length = (UInt16)len;
}

OSStatus FSPathMakeRef(const UInt8 *path, FSRef *ref, Boolean *isDirectory)
{
	char abs[PATH_MAX]; struct stat st;
	if (!path || !ref) return paramErr;
	if (!realpath((const char *)path, abs)) { if (lstat((const char *)path, &st) != 0) return fnfErr; strlcpy(abs, (const char *)path, sizeof abs); }
	if (lstat(abs, &st) != 0) return fnfErr;
	put_path(ref, abs);
	if (isDirectory) *isDirectory = S_ISDIR(st.st_mode) ? true : false;
	return noErr;
}
OSStatus FSRefMakePath(const FSRef *ref, UInt8 *path, UInt32 maxPathSize)
{
	if (!ref || !path) return paramErr;
	if (strlen(ref_path(ref)) + 1 > maxPathSize) return paramErr;
	strcpy((char *)path, ref_path(ref));
	return noErr;
}
OSStatus FSGetCatalogInfo(const FSRef *ref, FSCatalogInfoBitmap which, FSCatalogInfo *ci, HFSUniStr255 *outName, void *spec, FSRef *parentRef)
{
	struct stat st; (void)spec;
	if (!ref || lstat(ref_path(ref), &st) != 0) return fnfErr;
	if (ci) fill_info(&st, which, ci);
	const char *slash = strrchr(ref_path(ref), '/');
	if (outName) name_from_utf8(outName, slash && slash[1] ? slash + 1 : ref_path(ref));
	if (parentRef) { char pp[PATH_MAX]; strlcpy(pp, ref_path(ref), sizeof pp); char *s = strrchr(pp, '/'); if (s && s != pp) *s = 0; else if (s) s[1] = 0; put_path(parentRef, pp); }
	return noErr;
}
OSStatus FSOpenIterator(const FSRef *container, FSIteratorFlags flags, FSIterator *it)
{
	(void)flags;
	if (!container || !it) return paramErr;
	DIR *d = opendir(ref_path(container));
	if (!d) return errno == ENOENT ? fnfErr : permErr;
	struct OpaqueFSIterator *i = calloc(1, sizeof *i);
	i->dir = d; strlcpy(i->path, ref_path(container), sizeof i->path);
	*it = i;
	return noErr;
}
OSStatus FSCloseIterator(FSIterator it)
{
	if (!it) return paramErr;
	if (it->dir) closedir(it->dir);
	free(it);
	return noErr;
}
OSStatus FSGetCatalogInfoBulk(FSIterator it, ItemCount maxObjects, ItemCount *actual, Boolean *changed, FSCatalogInfoBitmap which, FSCatalogInfo *infos, FSRef *refs, void *specs, HFSUniStr255 *names)
{
	(void)specs;
	if (!it || !actual) return paramErr;
	if (changed) *changed = false;
	ItemCount n = 0; struct dirent *e;
	while (n < maxObjects && (e = readdir(it->dir))) {
		if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
		char full[PATH_MAX]; struct stat st;
		snprintf(full, sizeof full, "%s%s%s", it->path, it->path[strlen(it->path) - 1] == '/' ? "" : "/", e->d_name);
		if (lstat(full, &st) != 0) continue;                       /* vanished while reading */
		if (infos) fill_info(&st, which, &infos[n]);
		if (refs) put_path(&refs[n], full);
		if (names) name_from_utf8(&names[n], e->d_name);
		n++;
	}
	*actual = n;
	return n == 0 ? errFSNoMoreItems : noErr;
}
OSStatus FSGetVolumeInfo(FSVolumeRefNum v, ItemCount idx, FSVolumeRefNum *actual, UInt32 which, void *info, HFSUniStr255 *name, FSRef *root)
{
	(void)v; (void)idx; (void)which; (void)info;
	if (actual) *actual = 1;
	if (name) name_from_utf8(name, "/");
	if (root) put_path(root, "/");
	return noErr;
}

/* Uniform type identifiers, minimally: equality, a small conformance hierarchy and the filename extension table for the common types. */
#include <CoreFoundation/CoreFoundation.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
CFStringRef kUTTagClassFilenameExtension, kUTTagClassMIMEType, kUTTypeData, kUTTypeItem, kUTTypeContent, kUTTypePlainText, kUTTypeText, kUTTypeApplicationBundle, kUTTypeFolder, kUTTypeDirectory, kUTTypeBundle;
__attribute__((constructor)) static void initUT(void)
{
	kUTTagClassFilenameExtension = CFSTR("public.filename-extension"); kUTTagClassMIMEType = CFSTR("public.mime-type");
	kUTTypeData = CFSTR("public.data"); kUTTypeItem = CFSTR("public.item"); kUTTypeContent = CFSTR("public.content"); kUTTypePlainText = CFSTR("public.plain-text");
	kUTTypeText = CFSTR("public.text"); kUTTypeApplicationBundle = CFSTR("com.apple.application-bundle"); kUTTypeFolder = CFSTR("public.folder");
	kUTTypeDirectory = CFSTR("public.directory"); kUTTypeBundle = CFSTR("com.apple.bundle");
}
Boolean UTTypeEqual(CFStringRef a, CFStringRef b) { if (!a || !b) return a == b; return CFStringCompare(a, b, kCFCompareCaseInsensitive) == kCFCompareEqualTo; }
static const char *parent_of(const char *u)
{
	static const char *t[][2] = { { "public.plain-text", "public.text" }, { "public.text", "public.data" }, { "public.data", "public.item" }, { "public.folder", "public.directory" },
	                              { "public.directory", "public.item" }, { "com.apple.application-bundle", "com.apple.bundle" }, { "com.apple.bundle", "public.directory" },
	                              { "public.content", "public.item" }, { "public.source-code", "public.plain-text" }, { "public.c-source", "public.source-code" } };
	for (size_t i = 0; i < sizeof t / sizeof t[0]; i++) if (!strcmp(t[i][0], u)) return t[i][1];
	return NULL;
}
Boolean UTTypeConformsTo(CFStringRef uti, CFStringRef to)
{
	char a[256], b[256]; if (!uti || !to) return false;
	if (!CFStringGetCString(uti, a, sizeof a, kCFStringEncodingUTF8) || !CFStringGetCString(to, b, sizeof b, kCFStringEncodingUTF8)) return false;
	for (const char *u = a; u; u = parent_of(u)) if (!strcasecmp(u, b)) return true;
	return false;
}
CFStringRef UTTypeCopyPreferredTagWithClass(CFStringRef u, CFStringRef c) { (void)u; (void)c; return NULL; }
CFStringRef UTTypeCreatePreferredIdentifierForTag(CFStringRef cls, CFStringRef tag, CFStringRef conf)
{
	(void)conf; if (!cls || !tag) return NULL;
	if (CFStringCompare(cls, CFSTR("public.filename-extension"), 0) == kCFCompareEqualTo) {
		if (!CFStringCompare(tag, CFSTR("txt"), kCFCompareCaseInsensitive)) return CFRetain(CFSTR("public.plain-text"));
		if (!CFStringCompare(tag, CFSTR("c"), kCFCompareCaseInsensitive)) return CFRetain(CFSTR("public.c-source"));
	}
	return CFStringCreateWithFormat(NULL, NULL, CFSTR("dyn.%@.%@"), cls, tag);
}
CFStringRef UTTypeCopyDescription(CFStringRef u) { (void)u; return NULL; }

#define MAC_EPOCH_TO_CF 3061152000.0
int32_t UCConvertSecondsToCFAbsoluteTime(uint32_t seconds, CFAbsoluteTime *t) { if (t) *t = (CFAbsoluteTime)seconds - MAC_EPOCH_TO_CF; return 0; }
int32_t UCConvertCFAbsoluteTimeToSeconds(CFAbsoluteTime t, uint32_t *seconds) { double s = t + MAC_EPOCH_TO_CF; if (seconds) *seconds = s < 0 ? 0 : (uint32_t)s; return 0; }

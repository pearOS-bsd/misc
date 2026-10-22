/* Uniform type identifiers: the C API of CoreServices (UTType.h) and the class UTType of UniformTypeIdentifiers, over the table of the reference Mac (launchservices/uti_table.json: 2407 types with their
 * conformances, tags and flags, tools/ut_dump.py, tools/ut_build.py). Rules were fitted on the real system with tools/utprobe: the preferred identifier of a tag is the first active declaration (four
 * exceptions are listed in the table); tags without a declaration (or not conforming to the requested type) give a dynamic identifier "dyn.<base 32>" built bit for bit as the system builds it. */
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

NSString *const UTTagClassFilenameExtension = @"public.filename-extension";
NSString *const UTTagClassMIMEType = @"public.mime-type";

static NSDictionary *gTypes;                 /* identifier (as declared) -> record */
static NSDictionary *gLower;                 /* lowercased identifier -> identifier as declared */
static NSDictionary *gTags;                  /* "ext:txt" -> [identifiers] in declaration order */
static NSDictionary *gPrefer, *gCodes;

/* only ASCII letters change case (the system compares tags that way) */
static NSString *Low(NSString *s) { NSData *d = [s dataUsingEncoding: NSUTF8StringEncoding]; NSMutableData *m = [d mutableCopy]; unsigned char *p = [m mutableBytes]; for (NSUInteger i = 0; i < [m length]; i++) if (p[i] >= 'A' && p[i] <= 'Z') p[i] += 32; return [[NSString alloc] initWithData: m encoding: NSUTF8StringEncoding] ?: s; }
static NSString *TableClass(NSString *cls) { if ([cls isEqual: @"public.filename-extension"]) return @"ext"; if ([cls isEqual: @"public.mime-type"]) return @"mime"; if ([cls isEqual: @"com.apple.ostype"]) return @"ostype"; if ([cls isEqual: @"com.apple.nspboard-type"]) return @"pboard"; return nil; }
static void Load(void)
{
	static dispatch_once_t once; dispatch_once(&once, ^{
		const char *e = getenv("WSBSD_UTI_TABLE"); NSString *path = e ? @(e) : @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/uti_table.json";
		NSData *d = [NSData dataWithContentsOfFile: path]; NSDictionary *t = d ? [NSJSONSerialization JSONObjectWithData: d options: 0 error: NULL] : nil;
		NSMutableDictionary *types = [NSMutableDictionary dictionary], *lower = [NSMutableDictionary dictionary], *tags = [NSMutableDictionary dictionary];
		for (NSDictionary *r in t[@"types"]) {
			types[r[@"uti"]] = r; lower[[r[@"uti"] lowercaseString]] = r[@"uti"];
			for (NSString *k in @[ @"ext", @"mime", @"ostype", @"pboard" ]) for (NSString *v in r[@"tags"][k]) { NSString *key = [NSString stringWithFormat: @"%@:%@", k, [k isEqual: @"ostype"] ? v : Low(v)]; NSMutableArray *a = tags[key]; if (!a) a = tags[key] = [NSMutableArray array]; [a addObject: r[@"uti"]]; }
		}
		gTypes = types; gLower = lower; gTags = tags; gPrefer = t[@"prefer"] ?: @{}; gCodes = t[@"dyn_codes"] ?: @{};
	});
}

/* ---- dynamic identifiers: a bit stream of 8 bit elements, written in the 32 symbols "abcdefghkmnpqrstuvwxyz0123456789" ---- */
static const char kSym[] = "abcdefghkmnpqrstuvwxyz0123456789";
static NSString *kConfHeader = @"001111110011000000111101";   /* then the UTF-8 bytes of the identifier and ":" */
static NSString *CharBits(NSString *s) { NSMutableString *b = [NSMutableString string]; NSData *u = [s dataUsingEncoding: NSUTF8StringEncoding]; const unsigned char *p = [u bytes]; for (NSUInteger i = 0; i < [u length]; i++) for (int k = 7; k >= 0; k--) [b appendString: (p[i] >> k) & 1 ? @"1" : @"0"]; return b; }
static NSString *TagHeader(NSString *tableClass) { return [tableClass isEqual: @"mime"] ? @"0011001100111101" : [tableClass isEqual: @"ostype"] ? @"0011001000111101" : [tableClass isEqual: @"pboard"] ? @"0011010000111101" : @"0011000100111101"; }
static NSString *Symbols(NSString *bits)
{
	NSString *t = bits; while ([t hasSuffix: @"0"]) t = [t substringToIndex: [t length] - 1]; NSMutableString *b = [t mutableCopy]; while ([b length] % 5) [b appendString: @"0"];
	NSMutableString *out = [NSMutableString string]; for (NSUInteger i = 0; i < [b length]; i += 5) { int v = 0; for (int k = 0; k < 5; k++) v = v * 2 + ([b characterAtIndex: i + k] == '1'); [out appendFormat: @"%c", kSym[v]]; } return out;
}
static NSString *DynamicIdentifier(NSString *tableClass, NSString *tag, NSString *conformsTo)
{
	NSMutableString *bits = [NSMutableString stringWithString: @"00000"];
	if ([conformsTo length]) { NSString *known = gCodes[conformsTo] ?: gCodes[gLower[[conformsTo lowercaseString]] ?: @""]; if (known) [bits appendString: known]; else { [bits appendString: kConfHeader]; [bits appendString: CharBits(conformsTo)]; [bits appendString: @"00111010"]; } }
	[bits appendString: TagHeader(tableClass)]; [bits appendString: CharBits([tableClass isEqual: @"ostype"] ? tag : Low(tag))];
	return [@"dyn." stringByAppendingString: Symbols(bits)];
}
/* the conformance element and the tag of a dynamic identifier, or nil */
static BOOL DecodeDynamic(NSString *u, NSString **conf, NSString **cls, NSString **tag)
{
	if (![u hasPrefix: @"dyn."]) return NO; NSMutableString *bits = [NSMutableString string];
	for (NSUInteger i = 4; i < [u length]; i++) { const char *p = strchr(kSym, [u characterAtIndex: i]); if (!p || !*p) return NO; int v = (int)(p - kSym); for (int k = 4; k >= 0; k--) [bits appendString: (v >> k) & 1 ? @"1" : @"0"]; }
	if ([bits length] < 5) return NO; NSString *rest = [bits substringFromIndex: 5]; if (conf) *conf = nil;
	if ([rest hasPrefix: kConfHeader]) {
		for (NSString *code in gCodes) if ([rest hasPrefix: gCodes[code]]) { if (conf) *conf = code; rest = [rest substringFromIndex: [gCodes[code] length]]; goto tagpart; }
		NSMutableString *name = [NSMutableString string]; NSUInteger i = [kConfHeader length]; for (; i + 8 <= [rest length]; i += 8) { int v = (int)strtol([[rest substringWithRange: NSMakeRange(i, 8)] UTF8String], NULL, 2); if (v == 0x3A) { i += 8; break; } [name appendFormat: @"%c", v]; }
		if (conf) *conf = name; rest = i <= [rest length] ? [rest substringFromIndex: i] : @"";
	}
tagpart:
	for (NSString *c in @[ @"ext", @"mime", @"ostype", @"pboard" ]) {
		NSString *h = TagHeader(c); if (![rest hasPrefix: h]) continue; NSMutableString *name = [NSMutableString string]; NSMutableData *raw = [NSMutableData data]; NSUInteger i = [h length];
		for (; i + 8 <= [rest length]; i += 8) { int v = (int)strtol([[rest substringWithRange: NSMakeRange(i, 8)] UTF8String], NULL, 2); if (v == 0) break; unsigned char ch = (unsigned char)v; [raw appendBytes: &ch length: 1]; }
		[name appendString: [[NSString alloc] initWithData: raw encoding: NSUTF8StringEncoding] ?: @""]; if (cls) *cls = c; if (tag) *tag = name; return YES;
	}
	return NO;
}
static NSDictionary *Record(NSString *u) { Load(); NSDictionary *r = gTypes[u]; if (!r) { NSString *real = gLower[[u lowercaseString]]; r = real ? gTypes[real] : nil; } return r; }

/* ---- the C API ---- */
static NSString *Preferred(NSString *tc, NSString *tag, NSString *conf)
{
	Load(); if (!tc || !tag) return nil;
	NSString *key = [NSString stringWithFormat: @"%@:%@", tc, [tc isEqual: @"ostype"] ? tag : Low(tag)]; NSArray *cand = gTags[key]; NSString *pref = gPrefer[key];
	if (pref && [cand containsObject: pref]) { NSMutableArray *c2 = [cand mutableCopy]; [c2 removeObject: pref]; [c2 insertObject: pref atIndex: 0]; cand = c2; }
	for (NSString *u in cand) { if (![conf length]) return u; CFStringRef a = (__bridge CFStringRef)u, b = (__bridge CFStringRef)conf; if (UTTypeConformsTo(a, b)) return u; }
	return DynamicIdentifier(tc, tag, conf);
}
Boolean UTTypeEqual(CFStringRef a, CFStringRef b) { if (!a || !b) return a == b; return CFStringCompare(a, b, kCFCompareCaseInsensitive) == kCFCompareEqualTo; }
static BOOL Conforms(NSString *u, NSString *to, int depth)
{
	if ([u caseInsensitiveCompare: to] == NSOrderedSame) return YES; if (depth > 24) return NO;
	NSString *conf = nil; if (DecodeDynamic(u, &conf, NULL, NULL)) return [conf length] ? Conforms(conf, to, depth + 1) : NO;
	NSDictionary *r = Record(u); for (NSString *p in r[@"conforms"]) if (Conforms(p, to, depth + 1)) return YES;
	return NO;
}
Boolean UTTypeConformsTo(CFStringRef uti, CFStringRef to) { if (!uti || !to) return false; Load(); return Conforms((__bridge NSString *)uti, (__bridge NSString *)to, 0); }
CFStringRef UTTypeCreatePreferredIdentifierForTag(CFStringRef cls, CFStringRef tag, CFStringRef conf) { if (!cls || !tag) return NULL; NSString *r = Preferred(TableClass((__bridge NSString *)cls), (__bridge NSString *)tag, (__bridge NSString *)conf); return r ? (CFStringRef)CFBridgingRetain(r) : NULL; }
CFArrayRef UTTypeCreateAllIdentifiersForTag(CFStringRef cls, CFStringRef tag, CFStringRef conf)
{
	if (!cls || !tag) return NULL; Load(); NSString *tc = TableClass((__bridge NSString *)cls); if (!tc) return NULL; NSString *t = (__bridge NSString *)tag;
	NSArray *cand = gTags[[NSString stringWithFormat: @"%@:%@", tc, [tc isEqual: @"ostype"] ? t : Low(t)]]; NSMutableArray *out = [NSMutableArray array];
	for (NSString *u in cand) if (![(__bridge NSString *)conf length] || UTTypeConformsTo((__bridge CFStringRef)u, conf)) [out addObject: u];
	if (![out count]) [out addObject: DynamicIdentifier(tc, t, (__bridge NSString *)conf)]; return (CFArrayRef)CFBridgingRetain(out);
}
CFStringRef UTTypeCopyPreferredTagWithClass(CFStringRef uti, CFStringRef cls)
{
	if (!uti || !cls) return NULL; Load(); NSString *u = (__bridge NSString *)uti, *tc = TableClass((__bridge NSString *)cls); if (!tc) return NULL;
	NSString *dc = nil, *dt = nil; if (DecodeDynamic(u, NULL, &dc, &dt)) return [dc isEqual: tc] && [dt length] ? (CFStringRef)CFBridgingRetain(dt) : NULL;
	NSDictionary *r = Record(u); NSArray *a = r[@"tags"][tc]; return [a count] ? (CFStringRef)CFBridgingRetain(a[0]) : NULL;
}
CFStringRef UTTypeCopyDescription(CFStringRef uti) { if (!uti) return NULL; NSString *d = Record((__bridge NSString *)uti)[@"desc"]; return d ? (CFStringRef)CFBridgingRetain(d) : NULL; }
Boolean UTTypeIsDeclared(CFStringRef uti) { return uti && Record((__bridge NSString *)uti) != nil; }
Boolean UTTypeIsDynamic(CFStringRef uti) { return uti && [(__bridge NSString *)uti hasPrefix: @"dyn."]; }
CFDictionaryRef UTTypeCopyDeclaration(CFStringRef uti)
{
	if (!uti) return NULL; NSDictionary *r = Record((__bridge NSString *)uti); if (!r) return NULL;
	NSMutableDictionary *d = [NSMutableDictionary dictionary]; d[@"UTTypeIdentifier"] = r[@"uti"]; if (r[@"desc"]) d[@"UTTypeDescription"] = r[@"desc"]; if ([r[@"conforms"] count]) d[@"UTTypeConformsTo"] = r[@"conforms"];
	NSMutableDictionary *spec = [NSMutableDictionary dictionary]; if ([r[@"tags"][@"ext"] count]) spec[@"public.filename-extension"] = r[@"tags"][@"ext"]; if ([r[@"tags"][@"mime"] count]) spec[@"public.mime-type"] = r[@"tags"][@"mime"];
	if ([r[@"tags"][@"ostype"] count]) spec[@"com.apple.ostype"] = r[@"tags"][@"ostype"]; if ([r[@"tags"][@"pboard"] count]) spec[@"com.apple.nspboard-type"] = r[@"tags"][@"pboard"]; if ([spec count]) d[@"UTTypeTagSpecification"] = spec;
	return (CFDictionaryRef)CFBridgingRetain(d);
}

/* ---- the class UTType ---- */
@implementation UTType { NSString *_identifier; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)_initWithIdentifier:(NSString *)i { if ((self = [super init])) _identifier = [i copy]; return self; }
+ (UTType *)typeWithIdentifier:(NSString *)i { if (![i length]) return nil; Load(); NSDictionary *r = Record(i); if (!r && ![i hasPrefix: @"dyn."]) return nil; return [[UTType alloc] _initWithIdentifier: r ? r[@"uti"] : i]; }
+ (UTType *)typeWithFilenameExtension:(NSString *)e { return [self typeWithFilenameExtension: e conformingToType: nil]; }
+ (UTType *)typeWithFilenameExtension:(NSString *)e conformingToType:(UTType *)s { NSString *u = Preferred(@"ext", e, [s identifier]); return u ? [[UTType alloc] _initWithIdentifier: u] : nil; }
+ (UTType *)typeWithMIMEType:(NSString *)m { return [self typeWithMIMEType: m conformingToType: nil]; }
+ (UTType *)typeWithMIMEType:(NSString *)m conformingToType:(UTType *)s { NSString *u = Preferred(@"mime", m, [s identifier]); return u ? [[UTType alloc] _initWithIdentifier: u] : nil; }
+ (NSArray *)typesWithTag:(NSString *)tag tagClass:(UTTagClass)cls conformingToType:(UTType *)s { CFArrayRef a = UTTypeCreateAllIdentifiersForTag((__bridge CFStringRef)cls, (__bridge CFStringRef)tag, (__bridge CFStringRef)[s identifier]); NSMutableArray *o = [NSMutableArray array]; for (NSString *u in (__bridge_transfer NSArray *)a) [o addObject: [[UTType alloc] _initWithIdentifier: u]]; return o; }
- (NSString *)identifier { return _identifier; }
- (NSString *)preferredFilenameExtension { return (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_identifier, kUTTagClassFilenameExtension); }
- (NSString *)preferredMIMEType { return (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_identifier, kUTTagClassMIMEType); }
- (NSString *)localizedDescription { return Record(_identifier)[@"desc"]; }
- (NSDictionary *)tags { Load(); NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSDictionary *t = gTypes[_identifier][@"tags"]; if ([t[@"ext"] count]) d[UTTagClassFilenameExtension] = t[@"ext"]; if ([t[@"mime"] count]) d[UTTagClassMIMEType] = t[@"mime"]; return d; }
- (BOOL)isDeclared { return Record(_identifier) != nil; }
- (BOOL)isDynamic { return [_identifier hasPrefix: @"dyn."]; }
- (BOOL)isPublicType { return [_identifier hasPrefix: @"public."]; }
- (NSSet *)supertypes { Load(); NSMutableSet *out = [NSMutableSet set]; NSMutableArray *todo = [NSMutableArray arrayWithObject: _identifier]; NSString *conf; while ([todo count]) { NSString *u = [todo lastObject]; [todo removeLastObject]; NSArray *ps = DecodeDynamic(u, &conf, NULL, NULL) ? ([conf length] ? @[ conf ] : @[]) : Record(u)[@"conforms"]; for (NSString *p in ps) { UTType *t = [UTType typeWithIdentifier: p]; if (t && ![out containsObject: t]) { [out addObject: t]; [todo addObject: [t identifier]]; } } } return out; }
- (BOOL)conformsToType:(UTType *)t { return t && UTTypeConformsTo((__bridge CFStringRef)_identifier, (__bridge CFStringRef)[t identifier]); }
- (BOOL)isSubtypeOfType:(UTType *)t { return ![self isEqual: t] && [self conformsToType: t]; }
- (BOOL)isSupertypeOfType:(UTType *)t { return [t isSubtypeOfType: self]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass: [UTType class]] && [[o identifier] caseInsensitiveCompare: _identifier] == NSOrderedSame); }
- (NSUInteger)hash { return [[_identifier lowercaseString] hash]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: _identifier forKey: @"identifier"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self _initWithIdentifier: [c decodeObjectOfClass: [NSString class] forKey: @"identifier"]]; }
- (NSString *)description { return [NSString stringWithFormat: @"<UTType 0x%lx> %@", (unsigned long)self, _identifier]; }
#define T(name, ident) + (UTType *)name { return [UTType typeWithIdentifier: ident]; }
T(item, @"public.item") T(content, @"public.content") T(compositeContent, @"public.composite-content") T(diskImage, @"public.disk-image") T(data, @"public.data") T(directory, @"public.directory") T(resolvable, @"com.apple.resolvable") T(symbolicLink, @"public.symlink") T(executable, @"public.executable") T(mountPoint, @"com.apple.mount-point") T(aliasFile, @"com.apple.alias-file") T(urlBookmarkData, @"com.apple.bookmark")
T(url, @"public.url") T(fileURL, @"public.file-url") T(text, @"public.text") T(plainText, @"public.plain-text") T(utf8PlainText, @"public.utf8-plain-text") T(utf16PlainText, @"public.utf16-plain-text") T(rtf, @"public.rtf") T(html, @"public.html") T(xml, @"public.xml") T(sourceCode, @"public.source-code") T(cSource, @"public.c-source") T(json, @"public.json") T(pdf, @"com.adobe.pdf")
T(image, @"public.image") T(jpeg, @"public.jpeg") T(png, @"public.png") T(gif, @"com.compuserve.gif") T(tiff, @"public.tiff") T(audio, @"public.audio") T(mp3, @"public.mp3") T(movie, @"public.movie") T(video, @"public.video") T(archive, @"public.archive") T(zip, @"public.zip-archive") T(folder, @"public.folder") T(package, @"com.apple.package") T(bundle, @"com.apple.bundle") T(application, @"com.apple.application") T(applicationBundle, @"com.apple.application-bundle") T(propertyList, @"com.apple.property-list")
@end

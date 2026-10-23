/* .DS_Store, the file the Finder keeps its folder settings in (icon places `Iloc`, icon view `icvp`, window `bwsp`, ...): a "buddy allocator" file holding a B-tree of records (file name, structure id, type, value).
 * Read and written here after the format as the Mac's own files show it; a file written by this code was opened by the real Finder on a Mac and its icon places were honoured (see docs/desktop/DSStore.md).
 * Every record is kept as read, so settings of programs we know nothing about survive a rewrite. */
#import "TFinderViews.h"

static uint32_t R32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static void W32(NSMutableData *d, uint32_t v) { uint8_t b[4] = { (uint8_t)(v >> 24), (uint8_t)(v >> 16), (uint8_t)(v >> 8), (uint8_t)v }; [d appendBytes: b length: 4]; }

@implementation TDSStore
- (instancetype)initWithPath:(NSString *)path
{
	if ((self = [super init])) { _path = [path copy]; _records = [NSMutableArray array]; NSData *d = [NSData dataWithContentsOfFile: path]; if ([d length] > 36) [self _parse: d]; }
	return self;
}
+ (instancetype)storeForFolder:(NSString *)folder { return [[self alloc] initWithPath: [folder stringByAppendingPathComponent: @".DS_Store"]]; }
- (BOOL)_parse:(NSData *)data
{
	const uint8_t *b = (const uint8_t *)[data bytes]; NSUInteger len = [data length]; if (R32(b) != 1 || memcmp(b + 4, "Bud1", 4)) return NO;
	uint32_t roff = R32(b + 8), rsize = R32(b + 12); if ((NSUInteger)roff + 4 + rsize > len) return NO; const uint8_t *r = b + 4 + roff; uint32_t n = R32(r); if (8 + 4 * (NSUInteger)n > rsize) return NO;
	NSMutableArray *offs = [NSMutableArray array]; for (uint32_t i = 0; i < n; i++) [offs addObject: @(R32(r + 8 + 4 * i))]; NSUInteger p = 8 + 4 * (NSUInteger)n + 4 * ((256 - n % 256) % 256); if (p + 4 > rsize) return NO;
	uint32_t tc = R32(r + p); p += 4; uint32_t dsdb = UINT32_MAX;
	for (uint32_t i = 0; i < tc && p < rsize; i++) { uint8_t l = r[p]; NSString *nm = [[NSString alloc] initWithBytes: r + p + 1 length: l encoding: NSASCIIStringEncoding]; p += 1 + l; if ([nm isEqual: @"DSDB"]) dsdb = R32(r + p); p += 4; }
	if (dsdb >= n) return NO;
	const uint8_t *(^block)(uint32_t) = ^const uint8_t *(uint32_t i) { if (i >= n) return NULL; uint32_t a = [offs[i] unsignedIntValue]; NSUInteger o = (a & ~0x1fu), s = (NSUInteger)1 << (a & 0x1f); return o + 4 + s <= len ? b + 4 + o : NULL; };
	const uint8_t *h = block(dsdb); if (!h) return NO; uint32_t rootId = R32(h);
	__block BOOL ok = YES; __block void (^walk)(uint32_t, int) = nil; NSMutableArray *out = [NSMutableArray array];
	NSUInteger (^rec)(const uint8_t *, NSUInteger) = ^NSUInteger(const uint8_t *q, NSUInteger pos) {
		uint32_t nl = R32(q + pos); pos += 4; NSString *name = [[NSString alloc] initWithBytes: q + pos length: nl * 2 encoding: NSUTF16BigEndianStringEncoding]; pos += nl * 2;
		NSString *sid = [[NSString alloc] initWithBytes: q + pos length: 4 encoding: NSASCIIStringEncoding], *t = [[NSString alloc] initWithBytes: q + pos + 4 length: 4 encoding: NSASCIIStringEncoding]; pos += 8; id v = nil;
		if ([t isEqual: @"bool"]) { v = @(q[pos]); pos += 1; } else if ([t isEqual: @"long"] || [t isEqual: @"shor"]) { v = @(R32(q + pos)); pos += 4; }
		else if ([t isEqual: @"type"]) { v = [[NSString alloc] initWithBytes: q + pos length: 4 encoding: NSASCIIStringEncoding]; pos += 4; }
		else if ([t isEqual: @"comp"] || [t isEqual: @"dutc"]) { v = @(((uint64_t)R32(q + pos) << 32) | R32(q + pos + 4)); pos += 8; }
		else if ([t isEqual: @"blob"]) { uint32_t bl = R32(q + pos); v = [NSData dataWithBytes: q + pos + 4 length: bl]; pos += 4 + bl; }
		else if ([t isEqual: @"ustr"]) { uint32_t sl = R32(q + pos); v = [[NSString alloc] initWithBytes: q + pos + 4 length: sl * 2 encoding: NSUTF16BigEndianStringEncoding]; pos += 4 + sl * 2; }
		else { ok = NO; return pos; }
		[out addObject: [@[ name ?: @"", sid ?: @"", t ?: @"", v ?: @0 ] mutableCopy]]; return pos;
	};
	walk = ^(uint32_t i, int depth) {
		const uint8_t *q = block(i); if (!q || depth > 8 || !ok) { ok = NO; return; } uint32_t P = R32(q), cnt = R32(q + 4); NSUInteger pos = 8;
		for (uint32_t k = 0; k < cnt && ok; k++) { if (P) { uint32_t ch = R32(q + pos); pos += 4; walk(ch, depth + 1); } pos = rec(q, pos); }
		if (P && ok) walk(P, depth + 1);
	};
	walk(rootId, 0); walk = nil; if (!ok) return NO; _records = out; return YES;
}
- (NSMutableArray *)_find:(NSString *)name sid:(NSString *)sid { for (NSMutableArray *r in _records) if ([r[0] isEqual: name] && [r[1] isEqual: sid]) return r; return nil; }
- (id)valueForName:(NSString *)name sid:(NSString *)sid { return [self _find: name sid: sid][3]; }
- (void)setValue:(id)v type:(NSString *)t forName:(NSString *)name sid:(NSString *)sid { NSMutableArray *r = [self _find: name sid: sid]; if (r) { r[2] = t; r[3] = v; } else [_records addObject: [@[ name, sid, t, v ] mutableCopy]]; }
- (void)removeName:(NSString *)name sid:(NSString *)sid { NSMutableArray *r = [self _find: name sid: sid]; if (r) [_records removeObject: r]; }
- (BOOL)iconLocationOfName:(NSString *)name x:(int *)x y:(int *)y { NSData *d = [self valueForName: name sid: @"Iloc"]; if ([d length] < 8) return NO; const uint8_t *b = (const uint8_t *)[d bytes]; *x = (int)R32(b); *y = (int)R32(b + 4); return YES; }
- (void)setIconLocation:(NSPoint)c ofName:(NSString *)name { NSMutableData *d = [NSMutableData data]; W32(d, (uint32_t)(int)lround(c.x)); W32(d, (uint32_t)(int)lround(c.y)); const uint8_t tail[8] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0, 0 }; [d appendBytes: tail length: 8]; [self setValue: d type: @"blob" forName: name sid: @"Iloc"]; }
- (NSMutableDictionary *)plistForName:(NSString *)name sid:(NSString *)sid { NSData *d = [self valueForName: name sid: sid]; id pl = [d length] ? [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL] : nil; return [pl isKindOfClass: [NSMutableDictionary class]] ? pl : nil; }
- (void)setPlist:(NSDictionary *)pl forName:(NSString *)name sid:(NSString *)sid { NSData *d = [NSPropertyListSerialization dataWithPropertyList: pl format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; if (d) [self setValue: d type: @"blob" forName: name sid: sid]; }

static NSData *EncodeRecord(NSArray *r)
{
	NSMutableData *d = [NSMutableData data]; NSString *name = r[0], *t = r[2]; id v = r[3]; NSData *nb = [name dataUsingEncoding: NSUTF16BigEndianStringEncoding]; W32(d, (uint32_t)([nb length] / 2)); [d appendData: nb];
	[d appendData: [r[1] dataUsingEncoding: NSASCIIStringEncoding]]; [d appendData: [t dataUsingEncoding: NSASCIIStringEncoding]];
	if ([t isEqual: @"bool"]) { uint8_t b = [v unsignedCharValue]; [d appendBytes: &b length: 1]; } else if ([t isEqual: @"long"] || [t isEqual: @"shor"]) W32(d, [v unsignedIntValue]);
	else if ([t isEqual: @"type"]) [d appendData: [v dataUsingEncoding: NSASCIIStringEncoding]]; else if ([t isEqual: @"comp"] || [t isEqual: @"dutc"]) { uint64_t q = [v unsignedLongLongValue]; W32(d, (uint32_t)(q >> 32)); W32(d, (uint32_t)q); }
	else if ([t isEqual: @"blob"]) { W32(d, (uint32_t)[v length]); [d appendData: v]; } else if ([t isEqual: @"ustr"]) { NSData *u = [v dataUsingEncoding: NSUTF16BigEndianStringEncoding]; W32(d, (uint32_t)([u length] / 2)); [d appendData: u]; }
	return d;
}
- (BOOL)write
{
	NSArray *sorted = [_records sortedArrayUsingComparator: ^NSComparisonResult(NSArray *a, NSArray *b) { NSComparisonResult c = [[a[0] lowercaseString] compare: [b[0] lowercaseString] options: NSLiteralSearch]; return c != NSOrderedSame ? c : [a[1] compare: b[1]]; }];
	const NSUInteger PS = 4096; NSMutableArray *enc = [NSMutableArray array]; for (NSArray *r in sorted) [enc addObject: EncodeRecord(r)];
	NSMutableArray *leaves = [NSMutableArray array], *seps = [NSMutableArray array]; NSUInteger total = 8; for (NSData *e in enc) total += [e length];
	if (total <= PS) [leaves addObject: [enc mutableCopy]];
	else { NSUInteger i = 0; while (i < [enc count]) { NSMutableArray *cur = [NSMutableArray array]; NSUInteger sz = 8; while (i < [enc count] && sz + [enc[i] length] <= PS - 300) { [cur addObject: enc[i]]; sz += [enc[i] length]; i++; } [leaves addObject: cur]; if (i < [enc count]) { [seps addObject: enc[i]]; i++; } }
		if ([[leaves lastObject] count] == 0) [leaves removeLastObject]; if ([seps count] >= [leaves count]) { [[leaves lastObject] addObject: [seps lastObject]]; [seps removeLastObject]; } }
	NSMutableArray *nodes = [NSMutableArray array], *ids = [NSMutableArray array]; uint32_t nid = 2;
	for (NSArray *lf in leaves) { NSMutableData *n = [NSMutableData data]; W32(n, 0); W32(n, (uint32_t)[lf count]); for (NSData *e in lf) [n appendData: e]; [nodes addObject: n]; [ids addObject: @(nid++)]; }
	uint32_t rootId, levels = 0; if ([seps count]) { NSMutableData *n = [NSMutableData data]; W32(n, [[ids lastObject] unsignedIntValue]); W32(n, (uint32_t)[seps count]); for (NSUInteger k = 0; k < [seps count]; k++) { W32(n, [ids[k] unsignedIntValue]); [n appendData: seps[k]]; } [nodes addObject: n]; rootId = nid++; levels = 1; } else rootId = [ids[0] unsignedIntValue];
	if (PS < [[nodes lastObject] length]) return NO;
	NSMutableData *dsdb = [NSMutableData data]; W32(dsdb, rootId); W32(dsdb, levels); W32(dsdb, (uint32_t)[_records count]); W32(dsdb, (uint32_t)[nodes count]); W32(dsdb, (uint32_t)PS);
	NSMutableArray *blocks = [NSMutableArray arrayWithObject: [NSNull null]]; [blocks addObject: dsdb]; [blocks addObjectsFromArray: nodes]; NSUInteger nb = [blocks count];
	/* the buddy allocator: free blocks of every order, split on demand */
	NSMutableDictionary *freeL = [NSMutableDictionary dictionary]; for (int k = 5; k <= 30; k++) freeL[@(k)] = [NSMutableArray arrayWithObject: @((uint32_t)1 << k)];
	uint32_t (^alloc)(int) = ^uint32_t(int order) { int k = order; while (k <= 30 && ![freeL[@(k)] count]) k++; NSMutableArray *l = freeL[@(k)]; uint32_t off = [[l valueForKeyPath: @"@min.self"] unsignedIntValue]; [l removeObject: @(off)]; while (k > order) { k--; [freeL[@(k)] addObject: @(off + ((uint32_t)1 << k))]; } return off; };
	int (^orderFor)(NSUInteger) = ^int(NSUInteger n) { int o = 5; while (((NSUInteger)1 << o) < n) o++; return o; };
	NSMutableArray *addrs = [NSMutableArray array]; for (NSUInteger i = 0; i < nb; i++) [addrs addObject: @0]; NSMutableDictionary *placed = [NSMutableDictionary dictionary];
	for (NSUInteger i = 1; i < nb; i++) { int o = orderFor([blocks[i] length]); uint32_t off = alloc(o); addrs[i] = @(off | o); placed[@(off)] = blocks[i]; }
	NSData *(^rootBlock)(void) = ^NSData *{ NSMutableData *r = [NSMutableData data]; W32(r, (uint32_t)nb); W32(r, 0); for (NSNumber *a in addrs) W32(r, [a unsignedIntValue]); for (NSUInteger k = 0; k < (256 - nb % 256) % 256; k++) W32(r, 0);
		W32(r, 1); uint8_t four[5] = { 4, 'D', 'S', 'D', 'B' }; [r appendBytes: four length: 5]; W32(r, 1);
		for (int k = 0; k < 32; k++) { NSArray *l = [freeL[@(k)] sortedArrayUsingSelector: @selector(compare:)] ?: @[]; W32(r, (uint32_t)[l count]); for (NSNumber *x in l) W32(r, [x unsignedIntValue]); } return r; };
	int ro = orderFor([rootBlock() length] + 64); uint32_t roff = alloc(ro); addrs[0] = @(roff | ro); NSData *root = rootBlock(); placed[@(roff)] = root;
	NSUInteger end = 0; for (NSNumber *k in placed) end = MAX(end, [k unsignedIntValue] + ((NSUInteger)1 << orderFor([placed[k] length] + (k.unsignedIntValue == roff ? 64 : 0))));
	NSMutableData *file = [NSMutableData dataWithLength: end + 4]; uint8_t *fb = (uint8_t *)[file mutableBytes]; fb[3] = 1; memcpy(fb + 4, "Bud1", 4); NSMutableData *hd = [NSMutableData data]; W32(hd, roff); W32(hd, (uint32_t)1 << ro); W32(hd, roff); memcpy(fb + 8, [hd bytes], 12);
	for (NSNumber *k in placed) { NSData *b = placed[k]; memcpy(fb + 4 + [k unsignedIntValue], [b bytes], [b length]); }
	return [file writeToFile: _path atomically: YES];
}
@end

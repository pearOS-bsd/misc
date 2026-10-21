/* AppleEvent descriptors in memory: a descriptor owns typed bytes, or (list / record) an ordered set of (keyword, descriptor) pairs. Nothing is delivered between processes. */
#import <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <CoreServices/AppleEvents.h>
#import <objc/runtime.h>
static char kItemType;                                                    /* the type of a stored item travels with its box */

@interface WsbsdAEBox : NSObject { @public NSMutableData *data; NSMutableArray *keys, *items; BOOL isList; } @end
@implementation WsbsdAEBox @end
static DescType ItemType(WsbsdAEBox *b) { return (DescType)[objc_getAssociatedObject(b, &kItemType) unsignedIntValue]; }
static void SetItemType(WsbsdAEBox *b, DescType t) { objc_setAssociatedObject(b, &kItemType, @(t), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static WsbsdAEBox *Box(const AEDesc *d) { return d && d->dataHandle ? (__bridge WsbsdAEBox *)d->dataHandle : nil; }
static void Make(AEDesc *out, DescType t, WsbsdAEBox *b) { out->descriptorType = t; out->dataHandle = (AEDataStorage)CFBridgingRetain(b); }
int16_t AECreateDesc(DescType t, const void *p, long n, AEDesc *out)
{
	if (!out) return -50; WsbsdAEBox *b = [WsbsdAEBox new]; b->data = [NSMutableData dataWithBytes: p length: (NSUInteger)(n > 0 ? n : 0)]; Make(out, t, b); return 0;
}
int16_t AEDisposeDesc(AEDesc *d) { if (!d) return -50; if (d->dataHandle) CFRelease((CFTypeRef)d->dataHandle); d->dataHandle = NULL; d->descriptorType = typeNull; return 0; }
int16_t AEDuplicateDesc(const AEDesc *d, AEDesc *out)
{
	WsbsdAEBox *b = Box(d); if (!out) return -50; if (!b) { out->descriptorType = d ? d->descriptorType : typeNull; out->dataHandle = NULL; return 0; }
	WsbsdAEBox *c = [WsbsdAEBox new]; c->isList = b->isList; c->data = [b->data mutableCopy];
	if (b->items) { c->keys = [b->keys mutableCopy]; c->items = [NSMutableArray array]; for (WsbsdAEBox *i in b->items) { AEDesc tmp; AEDesc src = { ItemType(i), (AEDataStorage)CFBridgingRetain(i) }; AEDuplicateDesc(&src, &tmp); CFRelease(src.dataHandle); SetItemType(Box(&tmp), ItemType(i)); [c->items addObject: (__bridge id)tmp.dataHandle]; CFRelease(tmp.dataHandle); } }
	Make(out, d->descriptorType, c); return 0;
}
long AEGetDescDataSize(const AEDesc *d) { return (long)[Box(d)->data length]; }
int16_t AEGetDescData(const AEDesc *d, void *p, long max) { WsbsdAEBox *b = Box(d); if (!b) return errAEDescNotFound; NSUInteger n = [b->data length]; if ((long)n > max) n = (NSUInteger)max; memcpy(p, [b->data bytes], n); return 0; }
int16_t AECreateList(const void *f, long fs, Boolean isRecord, AEDescList *out)
{
	WsbsdAEBox *b = [WsbsdAEBox new]; b->data = [NSMutableData dataWithBytes: f length: (NSUInteger)(fs > 0 ? fs : 0)]; b->keys = [NSMutableArray array]; b->items = [NSMutableArray array]; b->isList = !isRecord;
	Make(out, isRecord ? typeAERecord : typeAEList, b); return 0;
}
int16_t AECountItems(const AEDescList *l, long *n) { WsbsdAEBox *b = Box(l); if (!b || !b->items) return -50; *n = (long)[b->items count]; return 0; }
int16_t AEPutParamDesc(AppleEvent *ev, AEKeyword k, const AEDesc *d)
{
	WsbsdAEBox *b = Box(ev); if (!b || !b->items) return -50; AEDesc c; AEDuplicateDesc(d, &c); SetItemType(Box(&c), d->descriptorType);
	for (NSUInteger i = 0; i < [b->keys count]; i++) if (!b->isList && [b->keys[i] unsignedIntValue] == k) { b->items[i] = (__bridge id)c.dataHandle; CFRelease(c.dataHandle); return 0; }     /* a record replaces the same keyword */
	[b->keys addObject: @(k)]; [b->items addObject: (__bridge id)c.dataHandle]; CFRelease(c.dataHandle); return 0;
}
int16_t AEPutParamPtr(AppleEvent *ev, AEKeyword k, DescType t, const void *p, long n)
{
	AEDesc d; AECreateDesc(t, p, n, &d); int16_t r = AEPutParamDesc(ev, k, &d); AEDisposeDesc(&d); return r;
}
int16_t AEGetParamDesc(const AppleEvent *ev, AEKeyword k, DescType want, AEDesc *out)
{
	WsbsdAEBox *b = Box(ev); if (!b || !b->items) return -50;
	for (NSUInteger i = 0; i < [b->keys count]; i++) if ([b->keys[i] unsignedIntValue] == k) { AEDesc src = { ItemType(b->items[i]), (AEDataStorage)CFBridgingRetain(b->items[i]) }; int16_t r = want == typeWildCard || want == src.descriptorType ? AEDuplicateDesc(&src, out) : AECoerceDesc(&src, want, out); CFRelease(src.dataHandle); return r; }
	return errAEDescNotFound;
}
int16_t AEGetNthDesc(const AEDescList *l, long index, DescType want, AEKeyword *key, AEDesc *out)
{
	WsbsdAEBox *b = Box(l); if (!b || !b->items) return -50; if (index < 1 || index > (long)[b->items count]) return errAEDescNotFound;
	if (key) *key = [b->keys[(NSUInteger)index - 1] unsignedIntValue];
	AEDesc src = { ItemType(b->items[(NSUInteger)index - 1]), (AEDataStorage)CFBridgingRetain(b->items[(NSUInteger)index - 1]) }; int16_t r = want == typeWildCard || want == src.descriptorType ? AEDuplicateDesc(&src, out) : AECoerceDesc(&src, want, out); CFRelease(src.dataHandle); return r;
}
int16_t AECoerceDesc(const AEDesc *d, DescType to, AEDesc *out)
{
	if (d->descriptorType == to) return AEDuplicateDesc(d, out);
	WsbsdAEBox *b = Box(d); if (!b) return errAECoercionFail;
	BOOL text = d->descriptorType == typeChar || d->descriptorType == typeUTF8Text, toText = to == typeChar || to == typeUTF8Text;
	if (text && toText) return AEDuplicateDesc(d, out) == 0 ? (out->descriptorType = to, 0) : errAECoercionFail;
	if (d->descriptorType == typeUnicodeText && toText) { NSString *s = [[NSString alloc] initWithData: b->data encoding: NSUTF16LittleEndianStringEncoding]; NSData *u = [s dataUsingEncoding: NSUTF8StringEncoding]; return AECreateDesc(to, [u bytes], (long)[u length], out); }
	if (text && to == typeUnicodeText) { NSString *s = [[NSString alloc] initWithData: b->data encoding: NSUTF8StringEncoding]; NSData *u = [s dataUsingEncoding: NSUTF16LittleEndianStringEncoding]; return AECreateDesc(to, [u bytes], (long)[u length], out); }
	if (d->descriptorType == typeSInt32 && toText) { int32_t v = 0; memcpy(&v, [b->data bytes], MIN([b->data length], sizeof v)); NSData *u = [[NSString stringWithFormat: @"%d", v] dataUsingEncoding: NSUTF8StringEncoding]; return AECreateDesc(to, [u bytes], (long)[u length], out); }
	return errAECoercionFail;
}
int16_t AECreateAppleEvent(AEEventClass cls, AEEventID ident, const AEAddressDesc *target, AEReturnID rid, AETransactionID tid, AppleEvent *out)
{
	(void)rid; (void)tid; AECreateList(NULL, 0, true, out); AEPutParamPtr(out, keyEventClassAttr, typeNull, &cls, sizeof cls); AEPutParamPtr(out, keyEventIDAttr, typeNull, &ident, sizeof ident);
	if (target) AEPutParamDesc(out, 0x61646472 /* 'addr' */, target); return 0;
}
int16_t AEGetAttributePtr(const AppleEvent *ev, AEKeyword k, DescType want, DescType *actual, void *p, long max, long *actualSize)
{
	AEDesc d; int16_t r = AEGetParamDesc(ev, k, typeWildCard, &d); if (r) return r; if (actual) *actual = d.descriptorType; long n = AEGetDescDataSize(&d); if (actualSize) *actualSize = n; if (p) AEGetDescData(&d, p, max); AEDisposeDesc(&d); (void)want; return 0;
}
int16_t AESendMessage(const AppleEvent *ev, AppleEvent *reply, AESendMode mode, long timeout) { (void)ev; (void)mode; (void)timeout; if (reply) { reply->descriptorType = typeNull; reply->dataHandle = NULL; } return procNotFound; }

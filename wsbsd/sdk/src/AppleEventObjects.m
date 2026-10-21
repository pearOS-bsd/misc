/* NSAppleEventDescriptor and NSAppleEventManager: GNUstep declares both as empty classes, the behaviour is added here as categories. A descriptor keeps its state in one associated dictionary:
 * type, data, list items, record keywords, attributes. Events are delivered inside the process (the manager looks the handler up by class and id); nothing crosses processes. */
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat3.h>
#import <objc/runtime.h>
#include <CoreServices/AppleEvents.h>

static const char kState;
static NSMutableDictionary *St(NSAppleEventDescriptor *d) { NSMutableDictionary *s = objc_getAssociatedObject(d, &kState); if (!s) { s = [NSMutableDictionary dictionary]; objc_setAssociatedObject(d, &kState, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return s; }
static NSAppleEventDescriptor *Make(uint32_t type, NSData *data) { NSAppleEventDescriptor *d = [[NSAppleEventDescriptor alloc] init]; St(d)[@"type"] = @(type); if (data) St(d)[@"data"] = [data copy]; return d; }
static NSMutableArray *Items(NSAppleEventDescriptor *d) { NSMutableArray *a = St(d)[@"items"]; if (!a) { a = [NSMutableArray array]; St(d)[@"items"] = a; } return a; }
static NSMutableArray *Keys(NSAppleEventDescriptor *d) { NSMutableArray *a = St(d)[@"keys"]; if (!a) { a = [NSMutableArray array]; St(d)[@"keys"] = a; } return a; }
static NSMutableDictionary *Attrs(NSAppleEventDescriptor *d) { NSMutableDictionary *a = St(d)[@"attrs"]; if (!a) { a = [NSMutableDictionary dictionary]; St(d)[@"attrs"] = a; } return a; }

@implementation NSAppleEventDescriptor (WsbsdAE)
+ (NSAppleEventDescriptor *)nullDescriptor { return Make(typeNull, nil); }
+ (NSAppleEventDescriptor *)descriptorWithBoolean:(BOOL)b { return Make(typeBoolean, [NSData dataWithBytes: &(uint8_t){ b } length: 1]); }
+ (NSAppleEventDescriptor *)descriptorWithInt32:(int32_t)v { return Make(typeSInt32, [NSData dataWithBytes: &v length: 4]); }
+ (NSAppleEventDescriptor *)descriptorWithString:(NSString *)s { return Make(typeUTF8Text, [s dataUsingEncoding: NSUTF8StringEncoding]); }
+ (NSAppleEventDescriptor *)descriptorWithEnumCode:(uint32_t)v { return Make(typeEnumerated, [NSData dataWithBytes: &v length: 4]); }
+ (NSAppleEventDescriptor *)descriptorWithTypeCode:(uint32_t)v { return Make(typeType, [NSData dataWithBytes: &v length: 4]); }
+ (NSAppleEventDescriptor *)descriptorWithDescriptorType:(uint32_t)t data:(NSData *)d { return Make(t, d); }
+ (NSAppleEventDescriptor *)descriptorWithDescriptorType:(uint32_t)t bytes:(const void *)b length:(NSUInteger)n { return Make(t, [NSData dataWithBytes: b length: n]); }
+ (NSAppleEventDescriptor *)descriptorWithProcessIdentifier:(pid_t)pid { return Make('kpid', [NSData dataWithBytes: &pid length: sizeof pid]); }
+ (NSAppleEventDescriptor *)descriptorWithBundleIdentifier:(NSString *)b { return Make(typeApplicationBundleID, [b dataUsingEncoding: NSUTF8StringEncoding]); }
+ (NSAppleEventDescriptor *)listDescriptor { return Make(typeAEList, nil); }
+ (NSAppleEventDescriptor *)recordDescriptor { return Make(typeAERecord, nil); }
+ (NSAppleEventDescriptor *)appleEventWithEventClass:(uint32_t)c eventID:(uint32_t)i targetDescriptor:(NSAppleEventDescriptor *)t returnID:(int16_t)r transactionID:(int32_t)x
{
	NSAppleEventDescriptor *e = Make('aevt', nil); NSMutableDictionary *s = St(e); s[@"class"] = @(c); s[@"id"] = @(i); s[@"return"] = @(r); s[@"trans"] = @(x); if (t) Attrs(e)[@(keyAddressAttr)] = t; return e;
}
- (uint32_t)descriptorType { return (uint32_t)[St(self)[@"type"] unsignedIntValue]; }
- (NSData *)data { return St(self)[@"data"]; }
- (BOOL)booleanValue { NSData *d = [self data]; return [d length] && ((const uint8_t *)[d bytes])[0] != 0; }
- (int32_t)int32Value { NSData *d = [self data]; int32_t v = 0; if ([d length] >= 4) memcpy(&v, [d bytes], 4); else if ([d length] == 2) { int16_t s; memcpy(&s, [d bytes], 2); v = s; } return v; }
- (NSString *)stringValue { NSData *d = [self data]; if (!d) return nil; uint32_t t = [self descriptorType]; return [[NSString alloc] initWithData: d encoding: t == typeUnicodeText ? NSUTF16LittleEndianStringEncoding : NSUTF8StringEncoding]; }
- (uint32_t)enumCodeValue { uint32_t v = 0; NSData *d = [self data]; if ([d length] >= 4) memcpy(&v, [d bytes], 4); return v; }
- (uint32_t)typeCodeValue { return [self enumCodeValue]; }
- (NSInteger)numberOfItems { return (NSInteger)Items(self).count; }
- (uint32_t)eventClass { return (uint32_t)[St(self)[@"class"] unsignedIntValue]; }
- (uint32_t)eventID { return (uint32_t)[St(self)[@"id"] unsignedIntValue]; }
- (int16_t)returnID { return (int16_t)[St(self)[@"return"] intValue]; }
- (int32_t)transactionID { return (int32_t)[St(self)[@"trans"] intValue]; }
- (void)insertDescriptor:(NSAppleEventDescriptor *)d atIndex:(NSInteger)i                                    /* 1-based; 0 appends */
{
	NSMutableArray *a = Items(self); NSUInteger at = i <= 0 || (NSUInteger)i > a.count ? a.count : (NSUInteger)i - 1; [a insertObject: d atIndex: at]; [Keys(self) insertObject: @0 atIndex: at];
}
- (NSAppleEventDescriptor *)descriptorAtIndex:(NSInteger)i { NSMutableArray *a = Items(self); return i >= 1 && (NSUInteger)i <= a.count ? a[(NSUInteger)i - 1] : nil; }
- (void)removeDescriptorAtIndex:(NSInteger)i { NSMutableArray *a = Items(self); if (i >= 1 && (NSUInteger)i <= a.count) { [a removeObjectAtIndex: (NSUInteger)i - 1]; [Keys(self) removeObjectAtIndex: (NSUInteger)i - 1]; } }
- (void)setDescriptor:(NSAppleEventDescriptor *)d forKeyword:(uint32_t)k
{
	NSMutableArray *a = Items(self), *ks = Keys(self); NSUInteger i = [ks indexOfObject: @(k)]; if (i != NSNotFound) a[i] = d; else { [a addObject: d]; [ks addObject: @(k)]; }
}
- (NSAppleEventDescriptor *)descriptorForKeyword:(uint32_t)k { NSUInteger i = [Keys(self) indexOfObject: @(k)]; return i == NSNotFound ? nil : Items(self)[i]; }
- (void)removeDescriptorWithKeyword:(uint32_t)k { NSUInteger i = [Keys(self) indexOfObject: @(k)]; if (i != NSNotFound) { [Items(self) removeObjectAtIndex: i]; [Keys(self) removeObjectAtIndex: i]; } }
- (uint32_t)keywordForDescriptorAtIndex:(NSInteger)i { NSMutableArray *k = Keys(self); return i >= 1 && (NSUInteger)i <= k.count ? [k[(NSUInteger)i - 1] unsignedIntValue] : 0; }
- (void)setParamDescriptor:(NSAppleEventDescriptor *)d forKeyword:(uint32_t)k { [self setDescriptor: d forKeyword: k]; }
- (NSAppleEventDescriptor *)paramDescriptorForKeyword:(uint32_t)k { return [self descriptorForKeyword: k]; }
- (void)removeParamDescriptorWithKeyword:(uint32_t)k { [self removeDescriptorWithKeyword: k]; }
- (void)setAttributeDescriptor:(NSAppleEventDescriptor *)d forKeyword:(uint32_t)k { Attrs(self)[@(k)] = d; }
- (NSAppleEventDescriptor *)attributeDescriptorForKeyword:(uint32_t)k { return Attrs(self)[@(k)]; }
- (NSAppleEventDescriptor *)coerceToDescriptorType:(uint32_t)t
{
	uint32_t from = [self descriptorType]; if (from == t) return self;
	if ((from == typeUTF8Text || from == typeChar || from == typeUnicodeText) && (t == typeUTF8Text || t == typeChar)) return Make(t, [[self stringValue] dataUsingEncoding: NSUTF8StringEncoding]);
	if (t == typeSInt32 && (from == typeSInt16 || from == typeSInt32)) return [NSAppleEventDescriptor descriptorWithInt32: [self int32Value]];
	if (t == typeUTF8Text && from == typeSInt32) return [NSAppleEventDescriptor descriptorWithString: [NSString stringWithFormat: @"%d", [self int32Value]]];
	return nil;
}
@end

@implementation NSAppleEventManager (WsbsdAE)
static NSMutableDictionary *gHandlers; static NSAppleEventDescriptor *gCur, *gReply;
+ (NSAppleEventManager *)sharedAppleEventManager { static NSAppleEventManager *m; static dispatch_once_t o; dispatch_once(&o, ^{ m = [NSAppleEventManager new]; gHandlers = [NSMutableDictionary dictionary]; }); return m; }
static NSString *HKey(uint32_t c, uint32_t i) { return [NSString stringWithFormat: @"%08x%08x", c, i]; }
- (void)setEventHandler:(id)h andSelector:(SEL)s forEventClass:(uint32_t)c andEventID:(uint32_t)i { @synchronized (gHandlers) { gHandlers[HKey(c, i)] = @[ [NSValue valueWithNonretainedObject: h], NSStringFromSelector(s) ]; } }
- (void)removeEventHandlerForEventClass:(uint32_t)c andEventID:(uint32_t)i { @synchronized (gHandlers) { [gHandlers removeObjectForKey: HKey(c, i)]; } }
- (NSInteger)dispatchEvent:(NSAppleEventDescriptor *)e reply:(NSAppleEventDescriptor *)r
{
	NSArray *h; @synchronized (gHandlers) { h = gHandlers[HKey([e eventClass], [e eventID])]; if (!h) h = gHandlers[HKey([e eventClass], typeWildCard)]; }
	if (!h) return errAEEventNotHandled;
	id target = [h[0] nonretainedObjectValue]; SEL sel = NSSelectorFromString(h[1]); NSAppleEventDescriptor *oc = gCur, *orr = gReply; gCur = e; gReply = r;
	((void (*)(id, SEL, NSAppleEventDescriptor *, NSAppleEventDescriptor *))objc_msgSend)(target, sel, e, r); gCur = oc; gReply = orr; return 0;
}
- (NSAppleEventDescriptor *)currentAppleEvent { return gCur; }
- (NSAppleEventDescriptor *)currentReplyAppleEvent { return gReply; }
@end

static const char kDirect;
@implementation NSScriptCommand (WsbsdAE)
- (id)directParameter { return objc_getAssociatedObject(self, &kDirect); }
- (void)setDirectParameter:(id)p { objc_setAssociatedObject(self, &kDirect, p, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end
NSString *const NSWorkspaceLaunchConfigurationAppleEvent = @"NSWorkspaceLaunchConfigurationAppleEvent";

/* "2 hours ago", "in 3 days": English, one unit */
@implementation NSRelativeDateTimeFormatter
@synthesize dateTimeStyle, unitsStyle, formattingContext;
- (NSString *)localizedStringForDate:(NSDate *)date relativeToDate:(NSDate *)ref
{
	NSTimeInterval d = [date timeIntervalSinceDate: ref]; BOOL future = d > 0; long s = (long)llabs((long long)d); NSString *u; long n;
	if (s < 60) { if (s < 5) return @"now"; n = s; u = @"second"; } else if (s < 3600) { n = s / 60; u = @"minute"; } else if (s < 86400) { n = s / 3600; u = @"hour"; }
	else if (s < 86400 * 7) { n = s / 86400; u = @"day"; } else if (s < 86400 * 30) { n = s / (86400 * 7); u = @"week"; } else if (s < 86400 * 365) { n = s / (86400 * 30); u = @"month"; } else { n = s / (86400 * 365); u = @"year"; }
	NSString *amount = [NSString stringWithFormat: @"%ld %@%@", n, u, n == 1 ? @"" : @"s"]; return future ? [@"in " stringByAppendingString: amount] : [amount stringByAppendingString: @" ago"];
}
- (NSString *)stringForObjectValue:(id)o { return [o isKindOfClass: [NSDate class]] ? [self localizedStringForDate: o relativeToDate: [NSDate date]] : nil; }
- (BOOL)getObjectValue:(id *)o forString:(NSString *)s errorDescription:(NSString **)e { (void)o; (void)s; if (e) *e = @"not supported"; return NO; }
@end

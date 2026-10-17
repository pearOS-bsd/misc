/* Implementations of the methods declared in include/wsbsd/AppKitCompat.h. */
#import <wsbsd/AppKitCompat.h>
#import <objc/runtime.h>

static id getAssoc(id o, const void *key) { return objc_getAssociatedObject(o, key); }
static void setAssoc(id o, const void *key, id v) { objc_setAssociatedObject(o, key, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@implementation NSTextView (WsbsdCompat)
- (void)insertText:(id)string replacementRange:(NSRange)range
{
	if (range.location == NSNotFound) { [self insertText: string]; return; }
	NSString *plain = [string isKindOfClass: [NSAttributedString class]] ? [(NSAttributedString *)string string] : string;
	if ([self shouldChangeTextInRange: range replacementString: plain]) {
		if ([string isKindOfClass: [NSAttributedString class]]) [[self textStorage] replaceCharactersInRange: range withAttributedString: string];
		else [[self textStorage] replaceCharactersInRange: range withString: plain];
		[self didChangeText];
	}
}
static const char quoteKey;
- (BOOL)isAutomaticQuoteSubstitutionEnabled { NSNumber *n = getAssoc(self, &quoteKey); return n ? [n boolValue] : YES; }
- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)flag { setAssoc(self, &quoteKey, [NSNumber numberWithBool: flag]); }
@end

@implementation NSButton (WsbsdCompat)
static const char scalingKey;
- (NSImageScaling)imageScaling { NSNumber *n = getAssoc(self, &scalingKey); return n ? (NSImageScaling)[n intValue] : NSImageScaleProportionallyDown; }
- (void)setImageScaling:(NSImageScaling)s { setAssoc(self, &scalingKey, [NSNumber numberWithInt: (int)s]); }
@end

@implementation NSSegmentedControl (WsbsdCompat)
static const char tipsKey, scalesKey;
- (void)setToolTip:(NSString *)tip forSegment:(NSInteger)segment
{
	NSMutableDictionary *d = getAssoc(self, &tipsKey); if (!d) { d = [NSMutableDictionary dictionary]; setAssoc(self, &tipsKey, d); }
	if (tip) [d setObject: tip forKey: [NSNumber numberWithInteger: segment]]; else [d removeObjectForKey: [NSNumber numberWithInteger: segment]];
}
- (NSString *)toolTipForSegment:(NSInteger)segment { return [(NSDictionary *)getAssoc(self, &tipsKey) objectForKey: [NSNumber numberWithInteger: segment]]; }
- (void)setImageScaling:(NSImageScaling)s forSegment:(NSInteger)segment
{
	NSMutableDictionary *d = getAssoc(self, &scalesKey); if (!d) { d = [NSMutableDictionary dictionary]; setAssoc(self, &scalesKey, d); }
	[d setObject: [NSNumber numberWithInt: (int)s] forKey: [NSNumber numberWithInteger: segment]];
}
- (NSImageScaling)imageScalingForSegment:(NSInteger)segment { NSNumber *n = [(NSDictionary *)getAssoc(self, &scalesKey) objectForKey: [NSNumber numberWithInteger: segment]]; return n ? (NSImageScaling)[n intValue] : NSImageScaleProportionallyDown; }
@end

@implementation NSDocument (WsbsdCompat)
static const char draftKey;
- (BOOL)isDraft { return [(NSNumber *)getAssoc(self, &draftKey) boolValue]; }
- (void)setDraft:(BOOL)flag { setAssoc(self, &draftKey, [NSNumber numberWithBool: flag]); }
@end

@implementation NSPasteboard (WsbsdCompat)
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray *)types { return [self availableTypeFromArray: types] != nil; }
@end

@implementation NSAlert (WsbsdCompat)
static const char accessoryKey;
- (NSView *)accessoryView { return getAssoc(self, &accessoryKey); }
- (void)setAccessoryView:(NSView *)v { setAssoc(self, &accessoryKey, v); }
@end

@implementation NSColor (WsbsdCompat)
+ (NSColor *)linkColor { return [NSColor colorWithCalibratedRed: 0.0 green: 0.4 blue: 0.8 alpha: 1.0]; }
+ (NSColor *)separatorColor { return [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.1]; }
@end

@implementation NSAttributedString (WsbsdCompat)
- (void)enumerateAttributesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary *, NSRange, BOOL *))block
{
	NSUInteger end = NSMaxRange(range), i = range.location; BOOL stop = NO;
	NSMutableArray *runs = [NSMutableArray array];
	while (i < end) {
		NSRange r; NSDictionary *a = [self attributesAtIndex: i effectiveRange: &r];
		NSRange c = NSIntersectionRange(r, range); if (c.length == 0) break;
		[runs addObject: [NSArray arrayWithObjects: a ? a : [NSDictionary dictionary], [NSValue valueWithRange: c], nil]];
		i = NSMaxRange(c);
	}
	BOOL rev = (opts & NSAttributedStringEnumerationReverse) != 0;
	NSEnumerator *e = rev ? [runs reverseObjectEnumerator] : [runs objectEnumerator]; NSArray *run;
	while (!stop && (run = [e nextObject])) block([run objectAtIndex: 0], [[run objectAtIndex: 1] rangeValue], &stop);
}
- (void)enumerateAttribute:(NSString *)name inRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id, NSRange, BOOL *))block
{
	NSUInteger end = NSMaxRange(range), i = range.location; BOOL stop = NO;
	NSMutableArray *runs = [NSMutableArray array];
	while (i < end) {
		NSRange r; id v = [self attribute: name atIndex: i longestEffectiveRange: &r inRange: range];
		if (r.length == 0) break;
		[runs addObject: [NSArray arrayWithObjects: v ? v : [NSNull null], [NSValue valueWithRange: r], nil]];
		i = NSMaxRange(r);
	}
	BOOL rev = (opts & NSAttributedStringEnumerationReverse) != 0;
	NSEnumerator *e = rev ? [runs reverseObjectEnumerator] : [runs objectEnumerator]; NSArray *run;
	while (!stop && (run = [e nextObject])) { id v = [run objectAtIndex: 0]; block(v == [NSNull null] ? nil : v, [[run objectAtIndex: 1] rangeValue], &stop); }
}
@end

@implementation NSData (WsbsdCompat)
+ (id)dataWithContentsOfFile:(NSString *)path options:(NSUInteger)options error:(NSError **)error
{
	NSData *d = [NSData dataWithContentsOfFile: path];
	if (!d && error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 260 userInfo: [NSDictionary dictionaryWithObject: path forKey: NSFilePathErrorKey]];
	return d;
}
- (NSString *)base64Encoding { return [self base64EncodedStringWithOptions: 0]; }
@end

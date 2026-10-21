/* CFAttributedString as NSAttributedString. gnustep-corebase has its own CFAttributedString object, which is not an NSAttributedString: Opal's CoreText casts the CFAttributedStringRef it is given to an
 * NSAttributedString and sends it -length, which that object does not answer (CTLineCreateWithAttributedString of an application's text raises an exception). The CF functions are defined here over
 * NSAttributedString / NSMutableAttributedString, and win over the library's because this library comes first. Attribute dictionaries returned by the Get calls stay alive as long as the string and the next call. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static const char kKeep;
#define AS(x) ((__bridge NSAttributedString *)(x))
#define MAS(x) ((__bridge NSMutableAttributedString *)(x))
#define NSR(r) NSMakeRange((NSUInteger)(r).location, (NSUInteger)(r).length)
static CFAttributedStringRef Ret(id o) { return (CFAttributedStringRef)CFBridgingRetain(o); }
static CFDictionaryRef Keep(NSAttributedString *s, NSDictionary *d) { objc_setAssociatedObject(s, &kKeep, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return (__bridge CFDictionaryRef)d; }

CFTypeID CFAttributedStringGetTypeID(void) { return (CFTypeID)(uintptr_t)objc_getClass("NSAttributedString"); }
CFAttributedStringRef CFAttributedStringCreate(CFAllocatorRef a, CFStringRef str, CFDictionaryRef attrs) { return Ret([[NSAttributedString alloc] initWithString: (__bridge NSString *)str attributes: (__bridge NSDictionary *)attrs]); }
CFAttributedStringRef CFAttributedStringCreateCopy(CFAllocatorRef a, CFAttributedStringRef s) { return Ret([AS(s) copy]); }
CFAttributedStringRef CFAttributedStringCreateWithSubstring(CFAllocatorRef a, CFAttributedStringRef s, CFRange r) { return Ret([AS(s) attributedSubstringFromRange: NSR(r)]); }
CFIndex CFAttributedStringGetLength(CFAttributedStringRef s) { return (CFIndex)[AS(s) length]; }
CFStringRef CFAttributedStringGetString(CFAttributedStringRef s) { return (__bridge CFStringRef)[AS(s) string]; }
CFTypeRef CFAttributedStringGetAttribute(CFAttributedStringRef s, CFIndex loc, CFStringRef name, CFRange *eff)
{
	NSRange r; id v = [AS(s) attribute: (__bridge NSString *)name atIndex: (NSUInteger)loc effectiveRange: &r]; if (eff) *eff = CFRangeMake((CFIndex)r.location, (CFIndex)r.length);
	if (v) objc_setAssociatedObject(AS(s), &kKeep, @[ v ], OBJC_ASSOCIATION_RETAIN_NONATOMIC); return (__bridge CFTypeRef)v;
}
CFDictionaryRef CFAttributedStringGetAttributes(CFAttributedStringRef s, CFIndex loc, CFRange *eff)
{
	NSRange r; NSDictionary *d = [AS(s) attributesAtIndex: (NSUInteger)loc effectiveRange: &r]; if (eff) *eff = CFRangeMake((CFIndex)r.location, (CFIndex)r.length); return Keep(AS(s), d ?: @{});
}
CFTypeRef CFAttributedStringGetAttributeAndLongestEffectiveRange(CFAttributedStringRef s, CFIndex loc, CFStringRef name, CFRange inRange, CFRange *eff)
{
	NSRange r; id v = [AS(s) attribute: (__bridge NSString *)name atIndex: (NSUInteger)loc longestEffectiveRange: &r inRange: NSR(inRange)]; if (eff) *eff = CFRangeMake((CFIndex)r.location, (CFIndex)r.length);
	if (v) objc_setAssociatedObject(AS(s), &kKeep, @[ v ], OBJC_ASSOCIATION_RETAIN_NONATOMIC); return (__bridge CFTypeRef)v;
}
CFDictionaryRef CFAttributedStringGetAttributesAndLongestEffectiveRange(CFAttributedStringRef s, CFIndex loc, CFRange inRange, CFRange *eff)
{
	NSRange r; NSDictionary *d = [AS(s) attributesAtIndex: (NSUInteger)loc longestEffectiveRange: &r inRange: NSR(inRange)]; if (eff) *eff = CFRangeMake((CFIndex)r.location, (CFIndex)r.length); return Keep(AS(s), d ?: @{});
}
CFMutableAttributedStringRef CFAttributedStringCreateMutable(CFAllocatorRef a, CFIndex maxLength) { return (CFMutableAttributedStringRef)CFBridgingRetain([[NSMutableAttributedString alloc] init]); }
CFMutableAttributedStringRef CFAttributedStringCreateMutableCopy(CFAllocatorRef a, CFIndex maxLength, CFAttributedStringRef s) { return (CFMutableAttributedStringRef)CFBridgingRetain([AS(s) mutableCopy]); }
void CFAttributedStringBeginEditing(CFMutableAttributedStringRef s) { [MAS(s) beginEditing]; }
void CFAttributedStringEndEditing(CFMutableAttributedStringRef s) { [MAS(s) endEditing]; }
CFMutableStringRef CFAttributedStringGetMutableString(CFMutableAttributedStringRef s) { return (__bridge CFMutableStringRef)[MAS(s) mutableString]; }
void CFAttributedStringRemoveAttribute(CFMutableAttributedStringRef s, CFRange r, CFStringRef name) { [MAS(s) removeAttribute: (__bridge NSString *)name range: NSR(r)]; }
void CFAttributedStringReplaceString(CFMutableAttributedStringRef s, CFRange r, CFStringRef rep) { [MAS(s) replaceCharactersInRange: NSR(r) withString: (__bridge NSString *)rep]; }
void CFAttributedStringReplaceAttributedString(CFMutableAttributedStringRef s, CFRange r, CFAttributedStringRef rep) { [MAS(s) replaceCharactersInRange: NSR(r) withAttributedString: AS(rep)]; }
void CFAttributedStringSetAttribute(CFMutableAttributedStringRef s, CFRange r, CFStringRef name, CFTypeRef value)
{
	if (value) [MAS(s) addAttribute: (__bridge NSString *)name value: (__bridge id)value range: NSR(r)]; else [MAS(s) removeAttribute: (__bridge NSString *)name range: NSR(r)];
}
void CFAttributedStringSetAttributes(CFMutableAttributedStringRef s, CFRange r, CFDictionaryRef attrs, Boolean clear)
{
	if (clear) [MAS(s) setAttributes: (__bridge NSDictionary *)attrs range: NSR(r)]; else [MAS(s) addAttributes: (__bridge NSDictionary *)attrs range: NSR(r)];
}

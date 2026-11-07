/*
 * stubs.m — minimal stand-ins for the AppKit externals NSResponder.m needs,
 * so the class can be compiled and tested without the rest of AppKit.
 * In the real build these come from AppKit itself.
 */
#import <Foundation/Foundation.h>

/* Count beeps so the test can assert on them. */
int gNSBeepCount = 0;
void NSBeep(void) { gNSBeepCount++; }

/* Record the last KVO dependency key registered. */
NSString *gLastKVODependencyKey = nil;
void _NSAddKeyValueDependency(id object, NSString *key)
{
    (void)object;
    gLastKVODependencyKey = key;
}

@interface NSKeyValueDependencyInfo : NSObject
- (instancetype)initWithOwner:(id)owner;
@end

@implementation NSKeyValueDependencyInfo
- (instancetype)initWithOwner:(id)owner { (void)owner; return [super init]; }
@end

/* AppKit normalises rects here (NaN/inf guard, negative size). Pass-through for
 * the test — the values used are already well-formed. */
#import <CoreGraphics/CoreGraphics.h>
CGRect _NSViewValidateRect(CGRect r) { return r; }

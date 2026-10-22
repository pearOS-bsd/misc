/* For every CW* class that adopts NSSecureCoding: the keys (and kinds) its encodeWithCoder: writes for a default instance. Run on the Mac and on wsbsd, diff. */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
#import <objc/runtime.h>
@interface Spy : NSCoder { @public NSMutableArray *log; } @end
@implementation Spy
- (instancetype)init { if ((self = [super init])) log = [NSMutableArray array]; return self; }
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)requiresSecureCoding { return YES; }
- (void)encodeObject:(id)o forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:object", k]]; }
- (void)encodeConditionalObject:(id)o forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:conditional", k]]; }
- (void)encodeBool:(BOOL)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:bool=%d", k, v]]; }
- (void)encodeInt:(int)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:int=%d", k, v]]; }
- (void)encodeInt32:(int32_t)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:int32=%d", k, v]]; }
- (void)encodeInt64:(int64_t)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:int64=%lld", k, (long long)v]]; }
- (void)encodeInteger:(NSInteger)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:integer=%ld", k, (long)v]]; }
- (void)encodeFloat:(float)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:float", k]]; }
- (void)encodeDouble:(double)v forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:double", k]]; }
- (void)encodeBytes:(const uint8_t *)b length:(NSUInteger)n forKey:(NSString *)k { [log addObject: [NSString stringWithFormat: @"%@:bytes%lu", k, (unsigned long)n]]; }
@end
int main(void) { @autoreleasepool {
	unsigned int n = 0; Class *all = objc_copyClassList(&n); NSMutableArray *names = [NSMutableArray array];
	for (unsigned int i = 0; i < n; i++) { const char *nm = class_getName(all[i]); if (strncmp(nm, "CW", 2) == 0 && strncmp(nm, "CWMutable", 9) != 0 && strcmp(nm, "CWLocationChannel") != 0 && class_conformsToProtocol(all[i], @protocol(NSSecureCoding)) && [all[i] respondsToSelector: @selector(supportsSecureCoding)]) [names addObject: @(nm)]; }
	for (NSString *nm in [names sortedArrayUsingSelector: @selector(compare:)]) {
		Class c = NSClassFromString(nm); id o = nil; @try { o = [[c alloc] init]; } @catch (id e) { printf("%s: init EXC\n", [nm UTF8String]); continue; }
		if (!o) { printf("%s: nil\n", [nm UTF8String]); continue; }
		Spy *s = [Spy new]; @try { [o encodeWithCoder: s]; } @catch (id e) { printf("%s: encode EXC\n", [nm UTF8String]); continue; }
		printf("%s: %s\n", [nm UTF8String], [[s->log componentsJoinedByString: @" "] UTF8String]);
	}
} return 0; }

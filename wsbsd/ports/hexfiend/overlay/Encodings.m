/* Port of Encodings.swift */
#import "Hex_Fiend-Swift.h"
#import "AppDelegate.h"

@implementation Encodings {
	ChooseStringEncodingWindowController *chooseStringEncoding;
}

- (NSArray<NSNumber *> *)menuSystemEncodingsNumbers
{
	NSArray *fromDefaults = [[NSUserDefaults standardUserDefaults] objectForKey: @"MenuSystemEncodings"];
	if ([fromDefaults isKindOfClass: [NSArray class]]) return fromDefaults;
	return @[ @(NSASCIIStringEncoding), @(NSMacOSRomanStringEncoding), @(NSISOLatin1StringEncoding), @(NSISOLatin2StringEncoding),
	          @(NSUTF16LittleEndianStringEncoding), @(NSUTF16BigEndianStringEncoding) ];
}

- (void)setMenuSystemEncodingsNumbers:(NSArray<NSNumber *> *)newEncodings
{
	[[NSUserDefaults standardUserDefaults] setObject: newEncodings forKey: @"MenuSystemEncodings"];
	[AppDelegate.shared buildEncodingMenu];
}

- (NSArray<HFNSStringEncoding *> *)menuSystemEncodings
{
	HFEncodingManager *manager = [HFEncodingManager shared];
	NSMutableArray<HFNSStringEncoding *> *result = [NSMutableArray array];
	for (NSNumber *n in self.menuSystemEncodingsNumbers) {
		HFNSStringEncoding *e = [manager systemEncoding: n.unsignedIntegerValue];
		if (!e) { NSLog(@"Unknown encoding %@", n); continue; }
		[result addObject: e];
	}
	[result sortUsingComparator: ^NSComparisonResult(HFNSStringEncoding *a, HFNSStringEncoding *b) { return [a.name compare: b.name]; }];
	return result;
}

- (void)showEncodingsWindow
{
	if (!chooseStringEncoding) chooseStringEncoding = [[ChooseStringEncodingWindowController alloc] init];
	[chooseStringEncoding showWindow: nil];
}

- (void)reloadEncodingsWindowIfLoaded { [chooseStringEncoding reload]; }
@end

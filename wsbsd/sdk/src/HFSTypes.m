/* NSFileTypeForHFSTypeCode / NSHFSTypeCodeFromFileType of GNUstep's base are stubs that answer nil / 0 (NSHFSFileTypes.m). Cocoa answers the code in quotes, "'home'" for 'home', and nil for 0; a literal dictionary that holds the result (Sloth's IconUtils: @{ @"type": NSFileTypeForHFSTypeCode(kLockedIcon) }) raises with nil and the dispatch_once block that was building the icons never finished (a thread then spun on it for ever).
 * The application is linked with -Wl,--wrap=NSFileTypeForHFSTypeCode -Wl,--wrap=NSHFSTypeCodeFromFileType (ci/build-app.sh): its calls come here, the base library keeps its own symbols. */
#import <Foundation/Foundation.h>

NSString *__wrap_NSFileTypeForHFSTypeCode(NSUInteger code)
{
	if (code == 0) return nil;
	char b[7] = { '\'', (char)(code >> 24), (char)(code >> 16), (char)(code >> 8), (char)code, '\'', 0 };
	return [[NSString alloc] initWithBytes: b length: 6 encoding: NSMacOSRomanStringEncoding] ?: [NSString stringWithFormat: @"'%08lx'", (unsigned long)code];
}
NSUInteger __wrap_NSHFSTypeCodeFromFileType(NSString *s)
{
	if ([s length] != 6 || [s characterAtIndex: 0] != '\'' || [s characterAtIndex: 5] != '\'') return 0;
	NSUInteger c = 0; for (int i = 1; i <= 4; i++) c = (c << 8) | ((unsigned)[s characterAtIndex: i] & 0xff);
	return c;
}

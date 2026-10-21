/* os_log: see include/os/log.h */
#import <Foundation/Foundation.h>
#include <os/log.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void wsbsd_os_log(int type, const char *format, ...)
{
	if (type < 0x10 && !getenv("WSBSD_OSLOG")) return;                                      /* default, info and debug stay quiet unless asked for */
	NSMutableString *f = [NSMutableString stringWithUTF8String: format ?: ""]; NSRange r;
	while ((r = [f rangeOfString: @"%{"]).location != NSNotFound) { NSRange e = [f rangeOfString: @"}" options: 0 range: NSMakeRange(r.location, [f length] - r.location)]; if (e.location == NSNotFound) break; [f deleteCharactersInRange: NSMakeRange(r.location + 1, e.location - r.location)]; }
	va_list ap; va_start(ap, format); NSString *msg = [[NSString alloc] initWithFormat: f arguments: ap]; va_end(ap);
	fprintf(stderr, "%s[%d]: %s\n", getprogname() ?: "?", (int)getpid(), [msg UTF8String]);
}

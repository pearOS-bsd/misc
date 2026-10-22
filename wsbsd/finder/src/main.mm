/* Finder: /System/Library/CoreServices/Finder.app. The principal class is TApplication (Info.plist), the delegate TApplicationController. */
#import <AppKit/AppKit.h>
int main(int argc, char **argv)
{
	@autoreleasepool {
		Class principal = NSClassFromString(@"TApplication"); [(id)principal sharedApplication];
		id dc = NSClassFromString(@"TApplicationController"); id del = [dc respondsToSelector: @selector(sharedApplicationController)] ? [dc performSelector: @selector(sharedApplicationController)] : nil; if (del) [NSApp setDelegate: del];
		[NSApp run];
	}
	return 0;
}

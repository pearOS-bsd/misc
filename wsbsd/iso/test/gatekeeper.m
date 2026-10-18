/* Launch Services' check of a quarantined application: launchApplication: on a bundle that carries com.apple.quarantine asks "... is an app downloaded from the Internet. Are you sure you want to open it?";
 * the process prints the answer of the user it got (driven by the test through the window server). Usage: gatekeeper /path/App.app */
#import <AppKit/AppKit.h>
BOOL WsbsdQuarantineNeedsApproval(NSString *path);
int main(int argc, char **argv)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSString *app = [NSString stringWithUTF8String: argv[1]];
		printf("needs approval before: %d\n", (int)WsbsdQuarantineNeedsApproval(app)); fflush(stdout);
		BOOL ok = [[NSWorkspace sharedWorkspace] launchApplication: app];
		printf("launchApplication: %d\nneeds approval after: %d\n", (int)ok, (int)WsbsdQuarantineNeedsApproval(app)); fflush(stdout);
	}
	return 0;
}

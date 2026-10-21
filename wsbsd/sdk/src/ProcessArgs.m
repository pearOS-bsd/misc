/* The arguments and environment of the process for NSProcessInfo. GNUstep's own way (renaming main to gnustep_base_user_main when Foundation is included) does not work in C++, where the renamed function gets a mangled name:
 * the headers of this SDK leave main alone (ci/patch-gui-types.py sets GS_FAKE_MAIN to 0) and the dynamic loader hands the same values to this constructor. */
#import <Foundation/Foundation.h>
#include <stdlib.h>
__attribute__((constructor)) static void wsbsd_process_args(int argc, char **argv, char **envp)
{
	setenv("GNUSTEP_STRING_ENCODING", "NSUTF8StringEncoding", 0);                    /* macOS strings are UTF-8 in C: with no locale GNUstep would pick ASCII and raise on every non-ASCII path */
	if (argc > 0 && argv) [NSProcessInfo initializeWithArguments: argv count: argc environment: envp];
}

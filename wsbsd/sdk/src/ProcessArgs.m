/* Programs whose main() is in a C++ translation unit. GNUstep renames main to gnustep_base_user_main when Foundation is included and libgnustep-base's own main() calls that C symbol after it has recorded the
 * arguments; in C++ the renamed function has a mangled name and the library finds nothing ("could not find the main function of your program"). The C symbol defined here sits in front of the library's weak one: it looks
 * the program's mangled function up by its likely signatures and calls it. A C or Objective-C program defines the C symbol itself (the executable comes first) and never gets here. */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>

int gnustep_base_user_main(int argc, char **argv, char **envp)
{
	static const char *const names[] = {
		"_Z22gnustep_base_user_mainiPPKcS1_", "_Z22gnustep_base_user_mainiPPcS0_", "_Z22gnustep_base_user_mainiPPKc", "_Z22gnustep_base_user_mainiPPc", "_Z22gnustep_base_user_mainiPKPKc",
		"_Z22gnustep_base_user_mainiPKPKcS3_", "_Z22gnustep_base_user_mainiPPKcPS1_", "_Z22gnustep_base_user_mainiPPcPS0_", "_Z22gnustep_base_user_mainv", 0 };
	for (int i = 0; names[i]; i++) {
		int (*f)(int, char **, char **) = (int (*)(int, char **, char **))dlsym(RTLD_DEFAULT, names[i]);
		if (f) return f(argc, argv, envp);
	}
	fprintf(stderr, "\nGNUSTEP Internal Error: the main function of this C++ program was not found (it must be exported: link with -rdynamic).\n"); exit(1);
}

/* The +load methods of other libraries message AppKit classes while the images are being loaded, before main(): that needs the process arguments, which libgnustep-base records in its own main(). A constructor that
 * runs first (constructors without a priority run after the Objective-C registration) records them now through GSInitializeProcess(); the library's main() records them again, harmlessly. */
extern void GSInitializeProcess(int argc, char **argv, char **envp);
__attribute__((constructor(101))) static void wsbsd_process_defaults(int argc, char **argv, char **envp)
{
	setenv("GNUSTEP_STRING_ENCODING", "NSUTF8StringEncoding", 0);                    /* macOS strings are UTF-8 in C: with no locale GNUstep would pick ASCII and raise on every non-ASCII path */
	if (argc > 0 && argv) GSInitializeProcess(argc, argv, envp);
}

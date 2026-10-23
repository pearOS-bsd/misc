/* Finder: /System/Library/CoreServices/Finder.app. The principal class is TApplication (Info.plist), the delegate TApplicationController. */
#import <AppKit/AppKit.h>
#if defined(__FreeBSD__) && defined(__x86_64__)
#import <signal.h>
#import <ucontext.h>
#import <dlfcn.h>
#import <unistd.h>
#import <stdio.h>
/* FINDER_CRASHLOG=1: a crash prints the stack words that point into code (the return addresses), the receiver and the selector (a crash in the message dispatch has no frames of its own) */
static void CrashHandler(int sig, siginfo_t *si, void *ctx)
{
	ucontext_t *uc = (ucontext_t *)ctx; unsigned long *sp = (unsigned long *)uc->uc_mcontext.mc_rsp; char b[400];
	int n = snprintf(b, sizeof b, "Finder crash: signal %d rip %lx rdi %lx rsi %lx r10 %lx fault %p\n", sig, (unsigned long)uc->uc_mcontext.mc_rip, (unsigned long)uc->uc_mcontext.mc_rdi, (unsigned long)uc->uc_mcontext.mc_rsi, (unsigned long)uc->uc_mcontext.mc_r10, si->si_addr); write(2, b, n);
	{ Dl_info d0; if (dladdr((void *)sp[0], &d0)) { n = snprintf(b, sizeof b, "  caller %lx in %s base %lx offset %lx\n", sp[0], d0.dli_fname ? d0.dli_fname : "?", (unsigned long)d0.dli_fbase, sp[0] - (unsigned long)d0.dli_fbase); write(2, b, n); } }
	for (int i = 0; i < 12; i++) { Dl_info d; if (dladdr((void *)sp[i], &d) && d.dli_sname) { n = snprintf(b, sizeof b, "  sp[%d] %lx %s+%lu (%s)\n", i, sp[i], d.dli_sname, (unsigned long)((char *)sp[i] - (char *)d.dli_saddr), d.dli_fname ? d.dli_fname : "?"); write(2, b, n); } }
	_exit(139);
}
#endif
int main(int argc, char **argv)
{
#if defined(__FreeBSD__) && defined(__x86_64__)
	if (getenv("FINDER_CRASHLOG")) { struct sigaction sa; sa.sa_sigaction = CrashHandler; sigemptyset(&sa.sa_mask); sa.sa_flags = SA_SIGINFO; sigaction(SIGSEGV, &sa, NULL); sigaction(SIGBUS, &sa, NULL); }
#endif
	@autoreleasepool {
		Class principal = NSClassFromString(@"TApplication"); [(id)principal sharedApplication];
		id dc = NSClassFromString(@"TApplicationController"); id del = [dc respondsToSelector: @selector(sharedApplicationController)] ? [dc performSelector: @selector(sharedApplicationController)] : nil; if (del) [NSApp setDelegate: del];
		[NSApp run];
	}
	return 0;
}

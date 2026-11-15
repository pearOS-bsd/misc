// is the real text system (UIFoundation of the cache) usable without the real AppKit?
#define _XOPEN_SOURCE 600
#define _DARWIN_C_SOURCE
#include <ucontext.h>
#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <signal.h>
#include <execinfo.h>
static void segv(int sig, siginfo_t *si, void *uc) { ucontext_t *u = uc; unsigned long long rip = u->uc_mcontext->__ss.__rip; Dl_info di; fprintf(stderr, "rip %#llx rsp %#llx rax %#llx rdi %#llx rsi %#llx\n", rip, u->uc_mcontext->__ss.__rsp, u->uc_mcontext->__ss.__rax, u->uc_mcontext->__ss.__rdi, u->uc_mcontext->__ss.__rsi); if (dladdr((void*)rip, &di)) fprintf(stderr, "in %s (%s) + %ld\n", di.dli_sname ? di.dli_sname : "?", di.dli_fname, (long)((char*)rip - (char*)di.dli_saddr)); void *bt[40]; int n = backtrace(bt, 40); fprintf(stderr, "SEGV addr %p, %d frames\n", si->si_addr, n); backtrace_symbols_fd(bt, n, 2); _exit(1); }
#define M(r, o, s, ...) ((r (*)(id, SEL, ...))objc_msgSend)(o, sel_registerName(s), ##__VA_ARGS__)
int main(void) { @autoreleasepool { struct sigaction sa = {0}; sa.sa_sigaction = segv; sa.sa_flags = SA_SIGINFO; sigaction(SIGSEGV, &sa, 0); sigaction(SIGBUS, &sa, 0);
  void *h = dlopen("/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation", RTLD_NOW);
  fprintf(stderr, "textsys: dlopen UIFoundation = %p %s\n", h, h ? "" : dlerror());
  Class TS = objc_getClass("NSTextStorage"), LM = objc_getClass("NSLayoutManager"), TC = objc_getClass("NSTextContainer");
  fprintf(stderr, "textsys: classes %p %p %p\n", TS, LM, TC);
  if (!TS || !LM || !TC) return 1;
  id ts = M(id, M(id, TS, "alloc"), "initWithString:", @"Hello world, this is a text that has to wrap around the container width.");
  fprintf(stderr,"textsys: ts ok\n");
  id lm = M(id, M(id, LM, "alloc"), "init");
  fprintf(stderr,"textsys: lm ok\n");
  typedef id (*initsz)(id, SEL, CGSize); id tc = ((initsz)objc_msgSend)(M(id, TC, "alloc"), sel_registerName("initWithSize:"), CGSizeMake(150, 1e7));
  fprintf(stderr,"textsys: tc ok\n");
  M(void, lm, "addTextContainer:", tc); fprintf(stderr,"textsys: added tc\n"); M(void, ts, "addLayoutManager:", lm);
  fprintf(stderr,"textsys: added ts\n");
  typedef CGRect (*rectfn)(id, SEL, ...);
  fprintf(stderr,"textsys: ts length %lu\n", (unsigned long)M(NSUInteger, ts, "length"));
  fprintf(stderr,"textsys: font %p\n", ((id(*)(id,SEL,double))objc_msgSend)((id)objc_getClass("NSFont"), sel_registerName("systemFontOfSize:"), 13.0));
  fprintf(stderr,"textsys: glyphs %lu\n", (unsigned long)M(NSUInteger, lm, "numberOfGlyphs"));
  M(void, lm, "ensureLayoutForTextContainer:", tc);
  NSRange gr = ((NSRange(*)(id,SEL,id))objc_msgSend)(lm, sel_registerName("glyphRangeForTextContainer:"), tc);
  fprintf(stderr, "textsys: glyph range %lu+%lu\n", (unsigned long)gr.location, (unsigned long)gr.length);
  CGRect lf = ((rectfn)objc_msgSend_stret)(lm, sel_registerName("lineFragmentUsedRectForGlyphAtIndex:effectiveRange:"), 0, NULL);
  fprintf(stderr, "textsys: first line used rect %g,%g %gx%g\n", lf.origin.x, lf.origin.y, lf.size.width, lf.size.height);
  CGRect r = ((rectfn)objc_msgSend_stret)(lm, sel_registerName("usedRectForTextContainer:"), tc);
  fprintf(stderr, "textsys: used rect %g x %g, glyphs %lu\n", r.size.width, r.size.height, (unsigned long)M(NSUInteger, lm, "numberOfGlyphs"));
  return 0; } }

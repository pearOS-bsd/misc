#!/usr/bin/env python3
"""gen-stubs.py APP_BINARY... : run on the Mac next to the built /tmp/wsb/out/AppKit.  Writes stubs-extra.m: a definition for every symbol the app binds from AppKit/Cocoa that our AppKit does not export
(classes: empty subclasses of NSResponder; string constants; NSAppKitVersionNumber; functions and Swift overlay symbols: a stub that logs once and answers 0).  Usage: gen-stubs.py OUT.m AppKit.dylib app1 app2..."""
import re, subprocess, sys
out, dylib, apps = sys.argv[1], sys.argv[2], sys.argv[3:]
have = set(l.split()[-1] for l in subprocess.run(['nm', '-gU', dylib], capture_output=True, text=True).stdout.splitlines() if l.strip())
need = {}
for a in apps:
    for l in subprocess.run(['dyld_info', '-fixups', a], capture_output=True, text=True).stdout.splitlines():
        m = re.search(r'\bbind\s+(?:weak-bind\s+)?(AppKit|Cocoa|RecapPerformanceTesting|libswiftCoreImage|libswiftMetal|libswiftQuartzCore|libswiftSpatial)/(\S+)', l)
        if m: need.setdefault(m.group(1), set()).add(m.group(2))
import os
uif = set(open('/tmp/uif.txt').read().split()) if os.path.exists('/tmp/uif.txt') else set()		# classes of UIFoundation come through the re-export

def gen(path, syms, have):
    miss = sorted(s for s in syms if s not in have and not (s.startswith('_OBJC_CLASS_$_') and s[len('_OBJC_CLASS_$_'):] in uif))
    cls = [s[len('_OBJC_CLASS_$_'):] for s in miss if s.startswith('_OBJC_CLASS_$_')]
    o = ['#import <Foundation/Foundation.h>', '#include <stdio.h>', 'static void OpenStubLog(const char *n) { fprintf(stderr, "open: stub %s called\\n", n); }']
    for c in cls: o.append('@interface %s : NSObject @end @implementation %s @end' % (c, c))
    n = 0
    for s in miss:
        if s.startswith('_OBJC_'): continue
        name = s[1:]
        if name == 'NSAppKitVersionNumber': o.append('const double NSAppKitVersionNumber = 2600.0;'); continue
        if re.match(r'^NS[A-Za-z0-9]*(Notification|Name|Key|Type|Mode|Identifier|Option|Options|Attribute|AttributeName|Pboard|PboardType|Style|Tag|Value|Rule|Level)$', name):
            o.append('NSString *const %s = @"%s";' % (name, name)); continue
        n += 1
        o.append('void open_stub_%d(void) __asm__("_%s"); void open_stub_%d(void) { OpenStubLog("%s"); }' % (n, name, n, name.replace('"', '')))
    open(path, 'w').write('\n'.join(o) + '\n')
    print('%s: %d classes, %d other of %d missing' % (path, len(cls), n, len(miss)))

here = os.path.dirname(os.path.abspath(out))
gen(out, need.get('AppKit', set()) | need.get('Cocoa', set()), have)
for lib, syms in need.items():
    if lib in ('AppKit', 'Cocoa'): continue
    gen(os.path.join(here, 'stubs-lib-%s.m' % lib), syms, set())

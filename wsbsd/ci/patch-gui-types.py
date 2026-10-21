#!/usr/bin/env python3
"""libs-gui: the return types Apple's AppKit declares and applications rely on. GNUstep answers `id` or a raw NSArray, so `window.contentView.bounds`, `menu.itemArray.firstObject.action` or
`openPanel.URLs.lastObject.filePathURL` do not compile (property access on `id` is an error in clang). Each entry is one header line made as specific as Apple's.
usage: patch-gui-types.py GUI_HEADERS_DIR   (the Headers/AppKit directory of the source tree, or the installed one)"""
import sys
d = sys.argv[1]
T = [
    ("NSWindow.h", "- (id) contentView;", "- (NSView *) contentView;"),
    ("NSControl.h", "- (id)cell;", "- (__kindof NSCell *)cell;"),
    ("NSMenu.h", "- (NSArray*) itemArray;", "- (NSArray<NSMenuItem *> *) itemArray;"),
    ("NSOpenPanel.h", "- (NSArray *) URLs;", "- (NSArray<NSURL *> *) URLs;"),
    ("NSSplitViewController.h", "- (NSArray *) splitViewItems;", "- (NSArray<NSSplitViewItem *> *) splitViewItems;"),
    ("NSTableView.h", "- (NSArray *) tableColumns;", "- (NSArray<NSTableColumn *> *) tableColumns;"),
    ("NSView.h", "- (NSArray*) subviews;", "- (NSArray<__kindof NSView *> *) subviews;"),
]
for f, a, b in T:
    p = d + "/" + f
    try:
        s = open(p).read()
    except OSError:
        continue
    if b in s:
        continue
    if a not in s:
        print("patch-gui-types: not found in", f, ":", a)
        continue
    open(p, "w").write(s.replace(a, b, 1))

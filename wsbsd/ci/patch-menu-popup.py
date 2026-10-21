#!/usr/bin/env python3
"""libs-gui: -[NSMenu popUpMenuPositioningItem:atLocation:inView:] answers BOOL on macOS (YES when an item was chosen); GNUstep's returns void, so `if([menu popUp...])` does not compile.
The method now returns whether an item of the menu was highlighted when tracking ended.
usage: patch-menu-popup.py GUI_SOURCE_DIR"""
import sys
g = sys.argv[1]
def sub(path, a, b):
    s = open(path).read()
    if b in s:
        return
    assert a in s, (path, a)
    open(path, "w").write(s.replace(a, b, 1))
h = g + "/Headers/AppKit/NSMenu.h"
sub(h, "- (void) popUpMenuPositionItem: (NSMenuItem *)item\n                    atLocation: (NSPoint) point\n                        inView: (NSView *) view;\n- (void) popUpMenuPositioningItem:",
       "- (BOOL) popUpMenuPositionItem: (NSMenuItem *)item\n                    atLocation: (NSPoint) point\n                        inView: (NSView *) view;\n- (BOOL) popUpMenuPositioningItem:")
m = g + "/Source/NSMenu.m"
sub(m, "- (void) popUpMenuPositioningItem: (NSMenuItem *)item", "- (BOOL) popUpMenuPositioningItem: (NSMenuItem *)item")
sub(m, "                  controlViewWindow: w\n                      preferredEdge: NSMinYEdge\n                       selectedItem: selectedItem];\n}",
       "                  controlViewWindow: w\n                      preferredEdge: NSMinYEdge\n                       selectedItem: selectedItem];\n  return [mr highlightedItemIndex] >= 0;\n}")
sub(m, "- (void) popUpMenuPositionItem: (NSMenuItem *)item", "- (BOOL) popUpMenuPositionItem: (NSMenuItem *)item")
sub(m, "{\n  [self popUpMenuPositioningItem: item \n                      atLocation: point \n                          inView: view];\n}", "{\n  return [self popUpMenuPositioningItem: item \n                      atLocation: point \n                          inView: view];\n}")

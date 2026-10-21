#!/usr/bin/env python3
"""libs-gui, NSMenu: a delegate's menuNeedsUpdate: that adds items made the menu update itself, which asked the delegate again, without end (TextMate's tab menu overflowed the stack on the first key press). A menu that is already being
updated by its delegate does not ask again.
usage: patch-menu-delegate-reentry.py NSMenu.m"""
import sys
path = sys.argv[1]
s = open(path).read()
if "GSMenusInDelegateUpdate" in s:
    sys.exit(0)
old = """- (void) _updateMenuWithDelegate
{
  if ([_delegate respondsToSelector: @selector(menuNeedsUpdate:)])
    {
      [_delegate menuNeedsUpdate: self];
    }
"""
new = """static NSHashTable *GSMenusInDelegateUpdate;

- (void) _updateMenuWithDelegate
{
  if (GSMenusInDelegateUpdate == nil)
    {
      GSMenusInDelegateUpdate = [[NSHashTable hashTableWithOptions: NSPointerFunctionsObjectPointerPersonality] retain];
    }
  if ([GSMenusInDelegateUpdate containsObject: self])
    {
      return;
    }
  [GSMenusInDelegateUpdate addObject: self];
  NS_DURING
    {
      [self _gsUpdateMenuWithDelegate];
    }
  NS_HANDLER
    {
      [GSMenusInDelegateUpdate removeObject: self];
      [localException raise];
    }
  NS_ENDHANDLER
  [GSMenusInDelegateUpdate removeObject: self];
}

- (void) _gsUpdateMenuWithDelegate
{
  if ([_delegate respondsToSelector: @selector(menuNeedsUpdate:)])
    {
      [_delegate menuNeedsUpdate: self];
    }
"""
assert old in s
s = s.replace(old, new, 1)
open(path, "w").write(s)

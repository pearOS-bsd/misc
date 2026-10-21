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
    ("NSArrayController.h", "- (NSArray*) sortDescriptors;", "- (NSArray<NSSortDescriptor *> *) sortDescriptors;"),
    ("NSTextView.h", "- (NSArray *) selectedRanges;", "- (NSArray<NSValue *> *) selectedRanges;"),
    # option and style sets are integers (NS_OPTIONS / NS_ENUM): `withAnimation:0` and `style = 3` compile in C++
    ("NSTableView.h", "typedef enum _NSTableViewAnimationOptions\n{", "typedef NSUInteger NSTableViewAnimationOptions;\nenum _NSTableViewAnimationOptions\n{"),
    ("NSTableView.h", "  NSTableViewAnimationSlideRight = 0x40,\n} NSTableViewAnimationOptions;", "  NSTableViewAnimationSlideRight = 0x40,\n};"),
    ("NSSegmentedControl.h", "typedef enum _NSSegmentStyle {", "typedef NSInteger NSSegmentStyle;\nenum _NSSegmentStyle {"),
    ("NSSegmentedControl.h", "  NSSegmentStyleSmallSquare = 6\n} NSSegmentStyle;", "  NSSegmentStyleSmallSquare = 6\n};"),
]
F = [("NSDictionary.h", "GSKeysAndObjectsEnumeratorBlock, void, GS_GENERIC_TYPE_F(KeyT,id<NSCopying>)", "GSKeysAndObjectsEnumeratorBlock, void, id"),
     ("NSDictionary.h", "GSKeysAndObjectsPredicateBlock, BOOL, GS_GENERIC_TYPE_F(KeyT,id<NSCopying>)", "GSKeysAndObjectsPredicateBlock, BOOL, id"),
     # NSUUID.h renames the system's uuid_t for every file that includes it: a C++ class called uuid_t (TextMate's oak::uuid_t) then has two names in two translation units and does not link
     ("NSUUID.h", "#if\tdefined(uuid_t)\n#undef\tuuid_t\n#endif\n#define\tuuid_t\tgsuuid_t\n", "")]      # a block over a raw NSDictionary takes (id key, id obj, BOOL *stop), as on macOS
import os
fd = os.path.join(os.path.dirname(d), "Foundation") if os.path.isdir(os.path.join(os.path.dirname(d), "Foundation")) else None
# GNUstep's `#define main gnustep_base_user_main` gives a C++ main() a mangled name the library cannot call; the argument capture moves to a constructor of libwsbsdcompat (sdk/src/ProcessArgs.m)
gd = os.path.join(os.path.dirname(d), "GNUstepBase")
try:
    s = open(gd + "/GSConfig.h").read()
    if "#define GS_FAKE_MAIN\t1" in s:
        open(gd + "/GSConfig.h", "w").write(s.replace("#define GS_FAKE_MAIN\t1", "#define GS_FAKE_MAIN\t0"))
except OSError:
    pass
if fd:
    for f, a, b in F:
        p = fd + "/" + f
        try:
            s = open(p).read()
        except OSError:
            continue
        if a in s:
            open(p, "w").write(s.replace(a, b))
ALL = [("NSMenu.h", "id <NSMenuItem>", "NSMenuItem *"),                                         # menu items are objects of the class on macOS, not of a protocol
       ("NSTableColumn.h", "- (NSCell *) dataCell;", "- (__kindof NSCell *) dataCell;"),
       ("NSDragging.h", "@protocol NSDraggingInfo\n", "@protocol NSDraggingInfo\n@property BOOL animatesToDestination;\n- (void)enumerateDraggingItemsWithOptions:(NSUInteger)enumOpts forView:(NSView *)view classes:(NSArray *)classArray searchOptions:(NSDictionary *)searchOptions usingBlock:(void (^)(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop))block;\n")]
for f, a, b in ALL:
    p = d + "/" + f
    try:
        s = open(p).read()
    except OSError:
        continue
    if a not in s or (f == "NSDragging.h" and "animatesToDestination" in s):
        continue
    if f == "NSDragging.h":
        s = s.replace("@protocol NSDraggingInfo\n", "@class NSDraggingItem;\n" + b, 1)
    else:
        s = s.replace(a, b)
    open(p, "w").write(s)
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

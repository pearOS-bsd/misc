# Decompiled AppKit (1:1 reimplementation)

Goal: replace the GNUstep-based AppKit with AppKit reimplemented **1:1 from the real
`AppKit.framework` on the owner's Mac (macOS 27, build 26A5416b, arm64e)**, decompiled
with REA/ipsw and rewritten (same classes, selectors, ivars, behaviour). GNUstep stays
only as temporary scaffolding, retired class by class. Only Apple's original binaries are
banned; rewrites of decompiled logic are allowed.

See `docs/DECOMPILE-QUEUE.md` (AppKit row) and the memory note
`feedback_appkit_decompile_not_gnustep`.

## Source of truth / pipeline

AppKit is not a standalone binary on macOS 27 — it lives in the dyld shared cache:
`/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e`.

Extraction to a clean Mach-O is currently blocked:
- `ipsw dyld extract` fails remapping the `_objc_msgSend$<sel>` selector stubs on this cache.
- `dyldextractor` (pip) is too old for macOS 27 slide-info.
- `ipsw dyld split` (Apple `dsc_extractor.bundle`, now available via Xcode) extracts the
  **whole** cache (tens of GB) — not safe while the build disk is near full.

So we read the real AppKit **directly from the cache** with ipsw (no extraction):
- **1:1 interface** (superclass, protocols, ivars w/ types, properties, method list):
  `ipsw dyld macho <cache> <AppKit> --objc`  → `reference/*.h` (checked in as evidence).
- **method bodies (logic)**: `ipsw dyld disass <cache> --symbol '-[Class sel]' --symbol-image <AppKit>`
  → `evidence/*.txt`. Method logic is transcribed from this disassembly, never invented.

Reference interfaces live in `reference/`. Per-method disassembly evidence in `evidence/`.
Reimplementations in `src/`. Each class ships with a CI test and, once verified, the
GNUstep/placeholder version is retired.

When the build disk has room (or on another machine) we can also `ipsw dyld split` the
whole cache once and open AppKit in REA/Ghidra for C-pseudocode on the gnarly methods.

## Priority (owner's choice: visible core first)

NSResponder → NSView → NSWindow → NSApplication → NSMenu/NSMenuItem → NSControl/NSCell →
NSButton → NSTextView. NSResponder first because View/Window/Application inherit from it.

## Progress

| Class | Interface (1:1) | Disassembly | Reimplemented | CI | GNUstep retired |
|---|---|---|---|---|---|
| NSResponder | ✅ reference/NSResponder.h | ✅ evidence/ (17 methods) | ✅ src/NSResponder.m (chain, events, commands, first-responder) | ✅ 19/19 pass | pending integration |
| NSView | ✅ | ✅ evidence/nsview/ (23 methods) | ◑ src/NSView.m (geometry, hierarchy, isFlipped, isDescendantOf:, hitTest geometry; stage2: layout-feedback/layer/notifications) | ✅ 19/19 pass | pending integration |
| NSWindow | ✅ | ✅ evidence/window/ (13) | ◑ src/NSWindow.m (title, styleMask, contentView, delegate(weak), isVisible/order, firstResponder/makeFirstResponder:; stage2: server ordering, key/main, border view) | ✅ 15/15 pass | pending integration |
| NSApplication | ✅ | ✅ evidence/app/ | ◑ src/NSApplication.m (sharedApplication+NSApp, delegate(weak), mainMenu, isRunning, windows, sendAction:to:from:/targetForAction:) | ✅ 13/13 pass | pending integration |
| NSMenu | ✅ | ✅ evidence/menu/ (14) | ◑ src/NSMenu.m (title, item array, insert/add/remove, lookups; stage2: thread check, notifications, item.menu back-link) | ✅ 15/15 pass | pending integration |
| NSMenuItem | ✅ | ✅ evidence/menuitem/ (19) | ◑ src/NSMenuItem.m (title/action/target(weak)/tag/state/separator/submenu/keyEquiv + init + separatorItem; stage2: NSApp autoenable, NSMenu kind-check) | ✅ 16/16 pass | pending integration |
| NSControl | ✅ | ✅ evidence/nscontrol/ (22) | ◑ src/NSControl.m (cell mgmt, isEnabled, target/action/tag -> cell; stage2: value/font/continuous/performClick, sendAction:to: via NSApp) | ✅ 13/13 pass | pending integration |
| NSCell | ✅ | ✅ evidence/nscell/ (26) | ◑ src/NSCell.m (state/enabled/highlighted/type _cFlags, target/action/tag stubs; stage2: value/title/formatter, init) | ✅ 20/20 pass | pending integration |
| NSActionCell | ✅ | ✅ evidence/nsactioncell/ (9) | ✅ src/NSActionCell.m (target/action/tag/controlView over NSCell) | ✅ 11/11 pass | pending integration |
| NSButtonCell | ✅ | ✅ evidence/button/ | ◑ src/NSButtonCell.m (title, bezelStyle, buttonType over NSActionCell; stage2: _contents title, type masks) | ✅ (via button 14/14) | pending integration |
| NSButton | ✅ | ✅ evidence/button/ | ◑ src/NSButton.m (title/state/bezel/buttonType/target/action delegate to cell, buttonWithTitle:...; stage2: redisplay, sizeToFit) | ✅ 14/14 pass | pending integration |
| NSTextFieldCell | ✅ | ✅ evidence/textfield/ | ◑ src/NSTextFieldCell.m (stringValue; inherits NSCell flags; stage2: bg colour, _tfFlags, contents) | ✅ (via textfield 11/11) | pending integration |
| NSTextField | ✅ | ✅ evidence/textfield/ | ◑ src/NSTextField.m (stringValue, editable/selectable/bezeled/bordered -> cell, labelWithString:) | ✅ 11/11 pass | pending integration |
| NSTextView | ✅ | — | — | — | — |
| NSStepperCell | ✅ | ✅ evidence/stepper/ | ◑ src/NSStepperCell.m (min/max/increment/valueWraps/autorepeat; stage2: _stepperModel) | ✅ (via stepper 9/9) | pending integration |
| NSStepper | ✅ | ✅ evidence/stepper/ | ◑ src/NSStepper.m (numeric props -> cell) | ✅ 9/9 pass | pending integration |
| NSBox | ✅ | ✅ evidence/box/ | ◑ src/NSBox.m (boxType/borderType/titlePosition/transparent packed _bFlags, title, border/corner metrics; stage2: titleCell, drawing) | ✅ 14/14 pass | pending integration |
| NSSliderCell | ✅ | ✅ evidence/slider/ | ◑ src/NSSliderCell.m (min/max/altIncrement/tickMarks direct ivars; stage2: _sliderModel sync) | ✅ (via slider 6/6) | pending integration |
| NSSlider | ✅ | ✅ evidence/slider/ | ◑ src/NSSlider.m (props -> cell) | ✅ 6/6 pass | pending integration |
| NSProgressIndicator | ✅ | ✅ evidence/progress/ | ◑ src/NSProgressIndicator.m (min/max/doubleValue w/ clamp, incrementBy:, indeterminate/style; stage2: aux renderer, animation, drawing) | ✅ 14/14 pass | pending integration |
| NSImageCell | ✅ | ✅ evidence/image/ | ◑ src/NSImageCell.m (imageAlignment/scaling/frameStyle packed flags, image; stage2: NSImage, drawing) | ✅ (via imageview 7/7) | pending integration |
| NSImageView | ✅ | ✅ evidence/image/ | ◑ src/NSImageView.m (enum props + image -> cell) | ✅ 7/7 pass | pending integration |
| NSLevelIndicatorCell | ✅ | ✅ evidence/level/ | ◑ src/NSLevelIndicatorCell.m (min/max/warning/critical/ticks direct ivars) | ✅ (via level 7/7) | pending integration |
| NSLevelIndicator | ✅ | ✅ evidence/level/ | ◑ src/NSLevelIndicator.m (numerics -> cell) | ✅ 7/7 pass | pending integration |
| NSPopUpButtonCell | ✅ | ✅ evidence/popup/ | ◑ src/NSPopUpButtonCell.m (menu, selected index, pullsDown, numberOfItems->menu; stage2: NSMenuItemCell base, popup tracking) | ✅ (via popup 12/12) | pending integration |
| NSPopUpButton | ✅ | ✅ evidence/popup/ | ◑ src/NSPopUpButton.m (menu ops -> cell; composes real NSMenu/NSMenuItem) | ✅ 12/12 pass | pending integration |
| NSTableColumn | ✅ | ✅ evidence/tablecol/ | ◑ src/NSTableColumn.m (identifier, width w/ min/max clamp, editable, title; stage2: headerCell, dataCell, sortDescriptor) | ✅ 9/9 pass | pending integration |
| NSClipView | ✅ | ✅ evidence/scroll/ | ◑ src/NSClipView.m (documentView _docView; stage2: bounds scrolling, frame observation) | ✅ (via scrollview 11/11) | pending integration |
| NSScrollView | ✅ | ✅ evidence/scroll/ | ◑ src/NSScrollView.m (contentView/documentView wiring, borderType _sFlags bits25-26, scroller flags; stage2: scroller views, scrolling) | ✅ 11/11 pass | pending integration |
| NSTabViewItem | ✅ | ✅ evidence/tab/ | ◑ src/NSTabViewItem.m (identifier/label/view; stage2: contents label routing) | ✅ (via tabview 12/12) | pending integration |
| NSTabView | ✅ | ✅ evidence/tab/ | ◑ src/NSTabView.m (item array, add/insert/remove, select, lookups; stage2: tab drawing/selection UI) | ✅ 12/12 pass | pending integration |
| NSSplitView | ✅ | ✅ evidence/split/ | ◑ src/NSSplitView.m (isVertical flag 0x40000, dividerStyle, dividerThickness derived; stage2: divider drag/layout, exact thickness) | ✅ 9/9 pass | pending integration |
| NSColorWell | ✅ | ✅ evidence/cwell/ | ◑ src/NSColorWell.m (color, active/bordered _cwFlags bits, activate:/deactivate; stage2: NSColor cluster, NSColorPanel) | ✅ 8/8 pass | pending integration |
| NSSegmentedCell | ✅ | ✅ evidence/seg/ | ◑ src/NSSegmentedCell.m (segment array, count w/ 0x800 cap, selection, per-segment label/width; stage2: packed segment records) | ✅ (via seg 10/10) | pending integration |
| NSSegmentedControl | ✅ | ✅ evidence/seg/ | ◑ src/NSSegmentedControl.m (segment ops -> cell) | ✅ 10/10 pass | pending integration |
| NSSearchFieldCell | ✅ | ✅ evidence/search/ | ◑ src/NSSearchFieldCell.m (maximumRecents bits1-8 w/ 0xff sentinel, sendsWholeSearchString bit0, recentSearches; stage2: search menu, init default) | ✅ (via search 9/9) | pending integration |
| NSSearchField | ✅ | ✅ evidence/search/ | ◑ src/NSSearchField.m (search props -> cell; inherits NSTextField) | ✅ 9/9 pass | pending integration |
| NSDatePickerCell | ✅ | ✅ evidence/date/ | ◑ src/NSDatePickerCell.m (min/max/dateValue, mode bits19-20 w/ ≤1 validation, style bits16-18; stage2: contents dateValue, calendar UI) | ✅ (via date 9/9) | pending integration |
| NSDatePicker | ✅ | ✅ evidence/date/ | ◑ src/NSDatePicker.m (date props -> cell) | ✅ 9/9 pass | pending integration |
| NSScroller | ✅ | ✅ evidence/scroller/ | ◑ src/NSScroller.m (knobProportion/doubleValue clamped [0,1], scrollerStyle bit9; stage2: knob hit-test/draw/live scroll) | ✅ 10/10 pass | pending integration |
| NSComboBoxCell | ✅ | ✅ evidence/combo/ | ◑ src/NSComboBoxCell.m (numberOfVisibleItems halfword cap 0xffff, usesDataSource bit0, item list; stage2: pop-up scroll view, data source) | ✅ (via combo 10/10) | pending integration |
| NSComboBox | ✅ | ✅ evidence/combo/ | ◑ src/NSComboBox.m (combo props -> cell; inherits NSTextField) | ✅ 10/10 pass | pending integration |
| NSTokenFieldCell | ✅ | ✅ evidence/token/ | ◑ src/NSTokenFieldCell.m (tokenStyle bits0-3 validated, completionDelay, tokenizingCharacterSet w/ default; stage2: token layout/represented objects) | ✅ (via token 10/10) | pending integration |
| NSTokenField | ✅ | ✅ evidence/token/ | ◑ src/NSTokenField.m (token props -> cell; inherits NSTextField) | ✅ 10/10 pass | pending integration |
| NSStackView | ✅ | ✅ evidence/stack/ | ◑ src/NSStackView.m (orientation, spacing, arrangedSubviews add/remove + real subview; stage2: auto-layout constraints, gravity areas) | ✅ 10/10 pass | pending integration |
| NSPathCell | ✅ | ✅ evidence/path/ | ◑ src/NSPathCell.m (pathStyle @0xa08, URL; stage2: contents URL, pathItems) | ✅ (via path 9/9) | pending integration |
| NSPathControl | ✅ | ✅ evidence/path/ | ◑ src/NSPathControl.m (pathStyle/URL/editable -> cell) | ✅ 9/9 pass | pending integration |
| NSTableView | ✅ | ✅ evidence/table/ | ◑ src/NSTableView.m (column add/remove/lookup, rowHeight reject≤0, allowsColumnReordering bit31; stage2: data source/delegate rows, view-based cells, header) | ✅ 11/11 pass | pending integration |
| NSOutlineView | ✅ | ✅ evidence/outline/ | ◑ src/NSOutlineView.m (indentationPerLevel int↔double clamp≥0, outlineTableColumn, autoresizesOutlineColumn bit3; inherits NSTableView; stage2: tree data source/expansion) | ✅ 10/10 pass | pending integration |
| NSToolbarItem | ✅ | ✅ evidence/tbitem/ | ◑ src/NSToolbarItem.m (itemIdentifier/label(nil→"")/paletteLabel/toolTip/tag/enabled/view; stage2: _loadViewIfNecessary flag gating, validation) | ✅ 10/10 pass | pending integration |
| NSColor | ✅ reference | ✅ evidence/color/ | blocked: class cluster (abstract base throws on redComponent; needs NSColorSpace + component/dynamic/catalog concrete subclasses) | — | — |

## Dependency order (corrected while working)

NSControl is cell-backed: target/action/value/enabled all delegate to its cell, and
sendAction:to: routes through NSApp. So the real order is:

  NSCell -> NSActionCell -> NSControl -> NSButtonCell -> NSButton

and NSControl.sendAction:to: also needs NSApplication. NSCell itself defines
target/action/tag only as throwing stubs ("Stub implementation of -setTarget by
NSCell does nothing.") — the real target/action/tag live in NSActionCell.

NSCell core state is a 64-bit `_cFlags` at ivar offset 0x10:
  - bit 0        state on/off
  - bit 1        highlighted  (isHighlighted)
  - bit 2        disabled     (isEnabled == !(bit2))
  - bits 4..5    cell type     (type)
  - bit 0x34     state mixed   (state == -1)
Value/title/stringValue/objectValue go through a contents+formatter helper tree
(0x18807c5b0 contents, 0x18809f840, 0x188079020, 0x1880b8fe0, 0x18803f4b0) that
must be decoded before NSCell can be reimplemented 1:1 and tested.

## NSCell flag bits (extended while doing NSTextField)

NSCell's _cFlags (64-bit at ivar 0x10) also holds: bit 3 editable, bit 8 bordered,
bit 9 bezeled, bit 10 selectable (isSelectable == _cFlags & 0x408, i.e.
editable|selectable). Bordered and bezeled are mutually exclusive. NSTextField/
NSButton expose these by delegating to the cell.

## NSColor is a class cluster (do not reimplement as one class)

+colorWithRed:green:blue:alpha: builds a component color through a private
factory over NSColorSpace; the abstract base NSColor throws
NSInvalidArgumentException on -redComponent ("need to first convert colorspace"),
-alphaComponent returns 1.0, and +blackColor/+redColor fault in dynamic/catalog
singletons. A 1:1 NSColor needs NSColorSpace plus the concrete subclasses
(component-based, dynamic-system, catalog) — a separate multi-class effort.

## Notes measured on this Mac

- NSResponder real ivars (macOS 27): `_nextResponder`, `_dependencyInfo` (NSKeyValueDependencyInfo),
  `_respondersWeAreNextFor` (NSPointerArray). GNUstep's NSResponder has only `_next_responder`
  and an interface-style flag — the dependency/KVO and "responders we are next for" tracking is new.

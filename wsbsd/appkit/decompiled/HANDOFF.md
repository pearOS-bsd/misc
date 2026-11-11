# AppKit 1:1 Decompile — Session Handoff

**Last updated:** 2026-11-11 · all green (`make` rc=0, 0 failures)

This file lets a fresh Claude session continue the AppKit decompile without
re-deriving context. Read it, read `README.md` (the per-class progress table =
source of truth), then resume the `/loop` producing one class per tick.

---

## 1. What this task is

Decompile macOS **AppKit 1:1 from the real framework** (not GNUstep) and
reimplement each public class *behaviorally*: same classes, same selectors,
same observable behaviour. GNUstep is only temporary scaffolding to retire
class-by-class. Evidence comes from the real AppKit binary via REA / `ipsw`
reading the dyld shared cache.

**Work model (agreed, standing):**
- Breadth-first **behavioral-1:1 cores** first — each class gets a core that
  reproduces its observable behaviour, with heavy internals marked
  `TODO(stage2)` / "stage2" (visual providers, window-server/CGS paths,
  layout engines, archiving internals).
- Every class ships with: (a) interface evidence from the binary, (b) a
  reimplemented `.h`/`.m`, (c) a passing standalone test.
- Deepen to bit-exact **only** where a real app breaks. NOT chasing
  byte-identical ivar layout.
- **Never ask the user to type "continue"** — just keep producing classes.
- Report **% of total** every tick. Denominators: **~230** public documented
  classes; **1679** total NS* symbols in the binary.
- Everything is **"pending integration"** into the BSD AppKit build — none of
  this is wired into pearOS UltraC0re yet (see §6).

---

## 2. Current state (counts)

| Metric | Value |
|---|---|
| Class rows in README, passing | **133** |
| `src/` headers | 148 |
| `test/` files | 133 |
| `evidence/` interface dumps | 150 |
| `make` suite | rc=0, **0 failures** |
| % of ~230 public API | **~58%** |

Last classes completed (2026-11-11 session): NSAffineTransform (AppKit category),
NSAnimation, NSViewAnimation, NSCollectionViewLayout (abstract base) +
NSCollectionViewFlowLayout + NSCollectionViewGridLayout, and the bindings family
NSController → NSObjectController → NSArrayController. Numeric/flag defaults for
the layout and controller classes were measured on this Mac by linking AppKit in
a throwaway probe (not invented).

---

## 3. Where everything lives

Working dir: `misc/wsbsd/appkit/decompiled/` (abs:
`/Users/alxb421/Desktop/app/misc/wsbsd/appkit/decompiled/`)

```
README.md              progress table — SOURCE OF TRUTH, one row per class
Makefile               one target per class; `make` / `make test` builds+runs all
HANDOFF.md             this file
src/NS*.{h,m}          reimplemented classes
test/test_*.m          one standalone test per class
test/stubs.m           shared test stubs
evidence/-NS*_interface.txt   saved `ipsw … --objc` interface dumps
```

Toolchain caches (outside repo):
- dyld cache: `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e`
- a2s cache: `~/appkit-decomp/dsc_arm64e.a2s`

Build flags: `OBJCFLAGS = -fobjc-arc -Wall -Wno-objc-root-class -g -O0`,
link `-framework Foundation -framework CoreGraphics` (some add `-framework CoreText`).
`CONTROL_SRC = NSControl.m NSView.m NSResponder.m NSCell.m NSActionCell.m
NSApplication.m NSMenu.m NSMenuItem.m` — any control-ish class links these.

---

## 4. The pipeline (exact commands)

**Interfaces (fast, use this every tick):**
```
ipsw dyld macho <cache> AppKit --objc        # whole-framework ObjC interface
ipsw dyld macho <cache> UIFoundation --objc  # text classes live here
```
Grep the output for the class, save to `evidence/-<Class>_interface.txt`.

**Disassembly (slow — do NOT block a tick on it):**
- `ipsw dyld disass` works ONLY **without** `--cache` (the saved a2s lacks ObjC
  method symbols). It parses ~21M symbols → ~5 min per run.
- So stage2 / CGS / window-server methods use the **binary interface** as
  evidence, not disasm. Only disassemble when a specific method's behaviour is
  genuinely unclear and an app depends on it.

---

## 5. Per-tick workflow

1. Pick the next public class not yet in README (check the skip-list below).
2. `ipsw dyld macho … --objc` → grep the class → save to `evidence/`.
3. Write `src/<Class>.h` (interface + evidence comment citing the binary) and
   `src/<Class>.m` (behavioral-1:1 core; stage2 internals annotated).
4. Write `test/test_<Class>.m` (checks observable behaviour; CHECK/gFails
   pattern; `return gFails==0?0:1`).
5. Add to `Makefile`: append `build/test_<class>` to the `test:` prereq list
   AND its run line, AND add the build rule.
6. Add a README row: `Class | Interface(1:1) | evidence | Reimplemented(stage2
   notes) | CI N/N pass | pending integration`.
7. `make` → confirm green.
8. Re-arm the loop (ScheduleWakeup) and report % (done/230).

**Loop mechanics:** dynamic `/loop`, re-armed each tick via `ScheduleWakeup`
(`delaySeconds=60, noop=false`, same tick prompt). Self-fires while the
terminal/session stays open; `caffeinate` keeps the Mac awake. **Cloud /schedule
CANNOT run this** — no access to this Mac's dyld cache / repo / ipsw / a2s.

---

## 6. BSD integration (not done — "pending integration")

Target stack: **swift-corelibs-foundation + libobjc2 + gnustep-base** on
FreeBSD. None of the decompiled classes are built there yet; the Makefile links
the macOS host frameworks. Eventual work: port the cores onto the BSD stack,
integrate into the real AppKit build, ship in **pearOS UltraC0re**
(ISO = `pearOS-UltraC0re-<arch>-26.10.iso`).

---

## 7. Skip-list / known gaps

- **NSLayoutConstraint** base — not in the interface dump as expected; revisit.
- **NSDiffableDataSourceSnapshot** — Swift-bridged, not a plain ObjC class.
- Classes whose entire body is a visual provider / window-server path: do the
  core + stage2 annotation, don't try to reproduce CGS.

---

## 8. Common pitfalls already hit (don't repeat)

- `*/` inside a comment closes the block early — reword.
- `template` is an ObjC++ keyword — use explicit getter/setter, not a property.
- ARC rejects `&staticVar` write-back out-params — return the instance instead.
- NSControl delegates target/action to its cell; cell-less controls (NSSwitch)
  must store their own; tests need `[NSApplication sharedApplication]` because
  `sendAction:` routes through NSApp.
- `copyWithZone:` must use `[[self class] alloc]` for polymorphic subclasses
  (NSTextBlock→NSTextTable/NSTextTableBlock).
- Grid/matrix classes: normalize ragged rows after growing columns.
- Pass nullable locals (not `nil`/`NULL` literals) to nonnull params in tests
  to silence `-Wnonnull`.

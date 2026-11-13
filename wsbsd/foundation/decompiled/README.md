# Foundation 1:1 behavioral-core decompile (pearOS UltraC0re / wsbsd)

Same model as `appkit/decompiled`: each class gets interface evidence from the
real Foundation binary (macOS 27, build 26A5416b, arm64e, via
`ipsw dyld macho … Foundation --objc`) or runtime measurement, a reimplemented
behavioral-1:1 `.h`/`.m` core, and a passing standalone test. Heavy internals
and the CoreFoundation toll-free bridge are annotated `stage2`. All classes are
"pending integration" (tested on the macOS host against the real Foundation; the
BSD stack currently uses GNUstep base — these cores replace it incrementally and
may sit on swift-corelibs-foundation where that is the cleaner real-Apple base).

| Class | Header | Evidence | Core (.m) | Test | Integration |
|---|---|---|---|---|---|
| NSNull | ✅ | ✅ evidence/-NSNull_interface.txt | ✅ src/NSNull.m (singleton null sentinel: +null (dispatch_once singleton), NSCopying (copy==self), description "<null>", NSSecureCoding (supportsSecureCoding YES, initWithCoder returns singleton); measured; standalone, no CF bridge) | ✅ 10/10 pass | pending integration |

> Host-test caveat: these cores are exercised on the macOS host against the real
> Foundation via granular sub-header imports (never the umbrella or the class\'s
> own header). The ObjC runtime then also holds CoreFoundation\'s copy of the
> class, so anything routed through host Foundation machinery (e.g.
> NSKeyedUnarchiver) resolves to THAT class; tests therefore call our methods
> directly. Full validation is on the FreeBSD/GNUstep (or swift-corelibs) stack
> where our class IS Foundation.
| NSIndexPath | ✅ | ✅ evidence/-NSIndexPath_interface.txt | ✅ src/NSIndexPath.m (immutable index list: +indexPathWithIndex:/WithIndexes:length:, length, indexAtPosition: (NSNotFound out of range — measured), getIndexes:range:, indexPathByAddingIndex:/RemovingLastIndex, lexicographic compare:, isEqual:/hash by contents, immutable copy; NSSecureCoding archive stage2) | ✅ 15/15 pass | pending integration |
| NSSortDescriptor | ✅ | ✅ evidence/-NSSortDescriptor_interface.txt | ✅ src/NSSortDescriptor.m (sort rule: +sortDescriptorWithKey:ascending:[selector:] (selector default compare: — measured), key/ascending/selector, reversedSortDescriptor flips direction, compareObject:toObject: reads valueForKey: + applies selector + negates when descending, immutable copy; block comparator + NSSecureCoding archive stage2) | ✅ 11/11 pass | pending integration |

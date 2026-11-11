/*
 * NSScrubberLayout.m — behavioral-1:1 abstract-base core. See NSScrubberLayout.h.
 */

#import "NSScrubberLayout.h"

@implementation NSScrubberLayout {
    __weak NSScrubber *_scrubber;
    BOOL _dirty;
}

+ (Class)layoutAttributesClass { return [NSScrubberLayoutAttributes class]; }

- (instancetype)init { self = [super init]; if (self) _dirty = YES; return self; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}

- (NSScrubber *)scrubber { return _scrubber; }
/* set by the scrubber when the layout is installed. */
- (void)_setScrubber:(NSScrubber *)s { _scrubber = s; }

- (void)invalidateLayout { _dirty = YES; }

/* --- base override points (concrete subclasses compute these) --- */
- (void)prepareLayout { _dirty = NO; }
- (NSSize)scrubberContentSize { return NSZeroSize; }
- (NSRect)visibleRect { return NSZeroRect; /* stage2: from the scrubber's scroll view */ }
- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)index { return nil; }
- (NSSet<NSScrubberLayoutAttributes *> *)layoutAttributesForItemsInRect:(NSRect)rect { return [NSSet set]; }
- (BOOL)shouldInvalidateLayoutForSelectionChange { return NO; }
- (BOOL)shouldInvalidateLayoutForHighlightChange { return NO; }
- (BOOL)shouldInvalidateLayoutForChangeFromVisibleRect:(NSRect)from toVisibleRect:(NSRect)to { return NO; }
- (BOOL)automaticallyMirrorsInRightToLeftLayout { return YES; }  /* measured */

@end

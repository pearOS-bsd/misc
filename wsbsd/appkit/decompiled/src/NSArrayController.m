/*
 * NSArrayController.m — behavioral-1:1 content/arrange/selection core.
 * See NSArrayController.h (defaults measured on this Mac; CoreData + KVO stage2).
 */

#import "NSArrayController.h"

@implementation NSArrayController {
    NSMutableArray *_objects;
    NSArray        *_arranged;
    NSMutableIndexSet *_selectionIndexes;
    NSArray<NSSortDescriptor *> *_sortDescriptors;
    NSPredicate    *_filterPredicate;
    BOOL _avoidsEmptySelection;
    BOOL _preservesSelection;
    BOOL _selectsInsertedObjects;
    BOOL _alwaysUsesMultipleValuesMarker;
    BOOL _clearsFilterPredicateOnInsertion;
    BOOL _automaticallyRearrangesObjects;
}

- (instancetype)initWithContent:(id)content
{
    self = [super initWithContent:nil];
    if (self) {
        _objects = content ? [content mutableCopy] : [NSMutableArray array];
        _selectionIndexes = [NSMutableIndexSet indexSet];
        _avoidsEmptySelection = YES;
        _preservesSelection = YES;
        _selectsInsertedObjects = YES;
        _alwaysUsesMultipleValuesMarker = NO;
        _clearsFilterPredicateOnInsertion = YES;
        _automaticallyRearrangesObjects = NO;
        [self rearrangeObjects];
    }
    return self;
}

- (instancetype)init { return [self initWithContent:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithContent:nil]; }

/* --- content --- */

- (id)content { return _objects; }

- (void)setContent:(id)content
{
    NSArray *previouslySelected = [self selectedObjects];
    _objects = content ? [content mutableCopy] : [NSMutableArray array];
    [self rearrangeObjects];
    if (_preservesSelection) [self _reselectObjects:previouslySelected];
    [self _enforceSelectionInvariants];
}

/* --- arrangement --- */

- (NSArray<NSSortDescriptor *> *)sortDescriptors { return _sortDescriptors; }
- (void)setSortDescriptors:(NSArray<NSSortDescriptor *> *)s { _sortDescriptors = [s copy]; [self rearrangeObjects]; [self _enforceSelectionInvariants]; }

- (NSPredicate *)filterPredicate { return _filterPredicate; }
- (void)setFilterPredicate:(NSPredicate *)p { _filterPredicate = p; [self rearrangeObjects]; [self _enforceSelectionInvariants]; }

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    NSArray *result = objects;
    if (_filterPredicate) result = [result filteredArrayUsingPredicate:_filterPredicate];
    if (_sortDescriptors.count) result = [result sortedArrayUsingDescriptors:_sortDescriptors];
    return result;
}

- (id)arrangedObjects { return _arranged ?: @[]; }

- (void)rearrangeObjects
{
    NSArray *selected = _selectionIndexes.count ? [self selectedObjects] : nil;
    _arranged = [self arrangeObjects:_objects];
    if (_preservesSelection && selected) [self _reselectObjects:selected];
}

/* --- selection helpers --- */

- (void)_reselectObjects:(NSArray *)objects
{
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    for (id obj in objects) {
        NSUInteger i = [_arranged indexOfObjectIdenticalTo:obj];
        if (i == NSNotFound) i = [_arranged indexOfObject:obj];
        if (i != NSNotFound) [set addIndex:i];
    }
    _selectionIndexes = set;
}

- (void)_enforceSelectionInvariants
{
    /* drop out-of-range indexes */
    NSMutableIndexSet *valid = [NSMutableIndexSet indexSet];
    NSUInteger n = [_arranged count];
    [_selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < n) [valid addIndex:idx];
    }];
    _selectionIndexes = valid;
    if (_avoidsEmptySelection && _selectionIndexes.count == 0 && n > 0)
        [_selectionIndexes addIndex:0];
}

/* --- content mutation --- */

- (void)addObject:(id)object
{
    if (_clearsFilterPredicateOnInsertion) _filterPredicate = nil;
    [_objects addObject:object];
    [self rearrangeObjects];
    if (_selectsInsertedObjects) [self _reselectObjects:@[object]];
    [self _enforceSelectionInvariants];
}

- (void)addObjects:(NSArray *)objects
{
    if (_clearsFilterPredicateOnInsertion) _filterPredicate = nil;
    [_objects addObjectsFromArray:objects];
    [self rearrangeObjects];
    if (_selectsInsertedObjects) [self _reselectObjects:objects];
    [self _enforceSelectionInvariants];
}

- (void)removeObject:(id)object
{
    [_objects removeObject:object];
    [self rearrangeObjects];
    [self _enforceSelectionInvariants];
}

- (void)removeObjects:(NSArray *)objects
{
    [_objects removeObjectsInArray:objects];
    [self rearrangeObjects];
    [self _enforceSelectionInvariants];
}

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index
{
    if (_clearsFilterPredicateOnInsertion) _filterPredicate = nil;
    /* map arranged index to the backing array (append when unsorted/ambiguous) */
    if (!_sortDescriptors.count && index <= _objects.count)
        [_objects insertObject:object atIndex:index];
    else
        [_objects addObject:object];
    [self rearrangeObjects];
    if (_selectsInsertedObjects) [self _reselectObjects:@[object]];
    [self _enforceSelectionInvariants];
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    if (index < [_arranged count]) {
        id obj = _arranged[index];
        [_objects removeObject:obj];
        [self rearrangeObjects];
        [self _enforceSelectionInvariants];
    }
}

/* --- selection --- */

- (NSIndexSet *)selectionIndexes { return [_selectionIndexes copy]; }
- (NSUInteger)selectionIndex { return _selectionIndexes.count ? _selectionIndexes.firstIndex : NSNotFound; }

- (NSArray *)selectedObjects
{
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger n = [_arranged count];
    [_selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < n) [out addObject:_arranged[idx]];
    }];
    return out;
}

- (BOOL)setSelectionIndexes:(NSIndexSet *)indexes
{
    _selectionIndexes = indexes ? [indexes mutableCopy] : [NSMutableIndexSet indexSet];
    [self _enforceSelectionInvariants];
    return YES;
}

- (BOOL)setSelectionIndex:(NSUInteger)index
{
    return [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:index]];
}

- (BOOL)addSelectionIndexes:(NSIndexSet *)indexes
{
    [_selectionIndexes addIndexes:indexes];
    [self _enforceSelectionInvariants];
    return YES;
}

- (BOOL)removeSelectionIndexes:(NSIndexSet *)indexes
{
    [_selectionIndexes removeIndexes:indexes];
    [self _enforceSelectionInvariants];
    return YES;
}

- (BOOL)setSelectedObjects:(NSArray *)objects { [self _reselectObjects:objects]; [self _enforceSelectionInvariants]; return YES; }
- (BOOL)addSelectedObjects:(NSArray *)objects
{
    NSArray *current = [self selectedObjects];
    [self _reselectObjects:[current arrayByAddingObjectsFromArray:objects]];
    [self _enforceSelectionInvariants];
    return YES;
}
- (BOOL)removeSelectedObjects:(NSArray *)objects
{
    NSMutableArray *current = [[self selectedObjects] mutableCopy];
    [current removeObjectsInArray:objects];
    [self _reselectObjects:current];
    [self _enforceSelectionInvariants];
    return YES;
}

/* --- selection navigation ---
 * selectNext:/selectPrevious: move the single selection index by ±1 within
 * arrangedObjects. (Measured note: in a controller with no live bindings the
 * real AppKit object deferred the move; the documented single-index advance is
 * reproduced here, deferral is stage2.) */

- (BOOL)canSelectNext { NSUInteger i = self.selectionIndex; return i != NSNotFound && (i + 1) < [_arranged count]; }
- (BOOL)canSelectPrevious { NSUInteger i = self.selectionIndex; return i != NSNotFound && i > 0; }

- (void)selectNext:(id)sender { if (self.canSelectNext) [self setSelectionIndex:self.selectionIndex + 1]; }
- (void)selectPrevious:(id)sender { if (self.canSelectPrevious) [self setSelectionIndex:self.selectionIndex - 1]; }

/* --- flags --- */

#define AC_BOOL(getter, setter, ivar) \
    - (BOOL)getter { return ivar; } \
    - (void)setter:(BOOL)v { ivar = v; }
AC_BOOL(avoidsEmptySelection, setAvoidsEmptySelection, _avoidsEmptySelection)
AC_BOOL(preservesSelection, setPreservesSelection, _preservesSelection)
AC_BOOL(selectsInsertedObjects, setSelectsInsertedObjects, _selectsInsertedObjects)
AC_BOOL(alwaysUsesMultipleValuesMarker, setAlwaysUsesMultipleValuesMarker, _alwaysUsesMultipleValuesMarker)
AC_BOOL(clearsFilterPredicateOnInsertion, setClearsFilterPredicateOnInsertion, _clearsFilterPredicateOnInsertion)
AC_BOOL(automaticallyRearrangesObjects, setAutomaticallyRearrangesObjects, _automaticallyRearrangesObjects)

/* --- actions / gating --- */

- (BOOL)canInsert { return self.isEditable; }
- (BOOL)canAdd { return self.isEditable; }
- (BOOL)canRemove { return self.isEditable && _selectionIndexes.count > 0; }

- (void)insert:(id)sender { if (self.canInsert) [self addObject:[self newObject]]; }
- (void)add:(id)sender { if (self.canAdd) [self addObject:[self newObject]]; }
- (void)remove:(id)sender { if (self.canRemove) [self removeObjects:[self selectedObjects]]; }

@end

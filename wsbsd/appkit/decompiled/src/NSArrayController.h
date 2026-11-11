/*
 * NSArrayController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSArrayController (: NSObjectController), the collection bindings controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSArrayController_interface.txt. Real ivars: _objects
 * (NSMutableArray backing), _arrangedObjects, _selectionIndexes, cached selected
 * indexes/objects, and a packed _arrayControllerFlags (avoidsEmptySelection /
 * preservesSelection / selectsInsertedObjects / …).
 *
 * Defaults MEASURED on this Mac: editable=YES, avoidsEmptySelection=YES,
 * preservesSelection=YES, selectsInsertedObjects=YES,
 * clearsFilterPredicateOnInsertion=YES, alwaysUsesMultipleValuesMarker=NO,
 * automaticallyRearrangesObjects=NO; content is an empty NSMutableArray;
 * arrangeObjects: filters then sorts; selectsInserted+avoidsEmpty drive the
 * selection on insert and on setContent:.
 *
 * This core reproduces the content/arrange/selection model over plain arrays.
 * The CoreData fetch path, KVO binding notifications (willChange…/didChange…),
 * marker objects, and automatic rearrangement observation are TODO(stage2).
 */

#import "NSObjectController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSArrayController : NSObjectController

/* arrangement */
@property (nullable, copy) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (nullable, strong) NSPredicate *filterPredicate;
@property (readonly, strong) id arrangedObjects;
- (NSArray *)arrangeObjects:(NSArray *)objects;
- (void)rearrangeObjects;

/* flags (measured defaults) */
@property BOOL avoidsEmptySelection;                  /* YES */
@property BOOL preservesSelection;                    /* YES */
@property BOOL selectsInsertedObjects;                /* YES */
@property BOOL alwaysUsesMultipleValuesMarker;        /* NO  */
@property BOOL clearsFilterPredicateOnInsertion;      /* YES */
@property BOOL automaticallyRearrangesObjects;        /* NO  */

/* content mutation */
- (void)addObject:(id)object;
- (void)addObjects:(NSArray *)objects;
- (void)removeObject:(id)object;
- (void)removeObjects:(NSArray *)objects;
- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index;

/* selection */
@property (readonly, copy) NSIndexSet *selectionIndexes;
@property (readonly) NSUInteger selectionIndex;
@property (readonly, copy) NSArray *selectedObjects;
- (BOOL)setSelectionIndexes:(NSIndexSet *)indexes;
- (BOOL)setSelectionIndex:(NSUInteger)index;
- (BOOL)addSelectionIndexes:(NSIndexSet *)indexes;
- (BOOL)removeSelectionIndexes:(NSIndexSet *)indexes;
- (BOOL)setSelectedObjects:(NSArray *)objects;
- (BOOL)addSelectedObjects:(NSArray *)objects;
- (BOOL)removeSelectedObjects:(NSArray *)objects;

/* selection navigation */
@property (readonly) BOOL canSelectNext;
@property (readonly) BOOL canSelectPrevious;
- (void)selectNext:(nullable id)sender;
- (void)selectPrevious:(nullable id)sender;

/* actions / gating */
@property (readonly) BOOL canInsert;
- (void)insert:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

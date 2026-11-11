/*
 * NSTreeController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTreeController (: NSObjectController), the hierarchical bindings controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTreeController_interface.txt. Real ivars: _rootNode,
 * _arrangedObjects, _selectionIndexPaths, _childrenKeyPath/_countKeyPath/
 * _leafKeyPath, _sortDescriptors, and a packed _treeControllerFlags.
 *
 * Defaults MEASURED on this Mac: editable=YES, avoidsEmptySelection=YES,
 * preservesSelection=YES, selectsInsertedObjects=YES,
 * alwaysUsesMultipleValuesMarker=NO; childrenKeyPath/countKeyPath/leafKeyPath=nil;
 * content=nil. -arrangedObjects RAISES NSInternalInconsistencyException
 * ("Cannot perform operation because childrenKeyPath is nil") when
 * childrenKeyPath is unset. With it set, arrangedObjects is a tree root whose
 * childNodes are NSTreeNodes built recursively from content via childrenKeyPath;
 * avoidsEmptySelection selects index path {0}.
 *
 * This core reproduces the tree-building + index-path selection model over
 * NSTreeNode (already decompiled). The CoreData fetch path, KVO binding
 * notifications, count/leaf key-path writeback and NSCoding are TODO(stage2).
 */

#import "NSObjectController.h"
#import "NSTreeNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTreeController : NSObjectController

/* key paths describing the model tree */
@property (nullable, copy) NSString *childrenKeyPath;
@property (nullable, copy) NSString *countKeyPath;
@property (nullable, copy) NSString *leafKeyPath;
@property (nullable, copy) NSArray<NSSortDescriptor *> *sortDescriptors;

@property (readonly, strong) NSTreeNode *arrangedObjects;
- (void)rearrangeObjects;

/* flags (measured defaults) */
@property BOOL avoidsEmptySelection;             /* YES */
@property BOOL preservesSelection;               /* YES */
@property BOOL selectsInsertedObjects;           /* YES */
@property BOOL alwaysUsesMultipleValuesMarker;   /* NO  */

/* selection by index path */
@property (readonly, copy) NSArray<NSIndexPath *> *selectionIndexPaths;
@property (readonly, copy, nullable) NSIndexPath *selectionIndexPath;
@property (readonly, copy) NSArray *selectedObjects;
@property (readonly, copy) NSArray<NSTreeNode *> *selectedNodes;
- (BOOL)setSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (BOOL)setSelectionIndexPath:(nullable NSIndexPath *)indexPath;
- (BOOL)addSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (BOOL)removeSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/* content mutation at index paths */
- (void)insertObject:(id)object atArrangedObjectIndexPath:(NSIndexPath *)indexPath;
- (void)removeObjectAtArrangedObjectIndexPath:(NSIndexPath *)indexPath;

/* new objects */
- (id)newObject;
- (nullable id)newChildObject;

/* actions / gating */
@property (readonly) BOOL canInsert;
@property (readonly) BOOL canInsertChild;
@property (readonly) BOOL canAddChild;
- (void)insert:(nullable id)sender;
- (void)add:(nullable id)sender;
- (void)addChild:(nullable id)sender;
- (void)remove:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

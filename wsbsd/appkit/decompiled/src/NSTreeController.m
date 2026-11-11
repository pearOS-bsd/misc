/*
 * NSTreeController.m — behavioral-1:1 tree-build + index-path selection core.
 * See NSTreeController.h (defaults measured on this Mac; CoreData + KVO stage2).
 */

#import "NSTreeController.h"

@implementation NSTreeController {
    id _content;
    NSString *_childrenKeyPath;
    NSString *_countKeyPath;
    NSString *_leafKeyPath;
    NSArray<NSSortDescriptor *> *_sortDescriptors;
    NSTreeNode *_root;
    NSMutableArray<NSIndexPath *> *_selectionIndexPaths;
    BOOL _avoidsEmptySelection;
    BOOL _preservesSelection;
    BOOL _selectsInsertedObjects;
    BOOL _alwaysUsesMultipleValuesMarker;
}

- (instancetype)initWithContent:(id)content
{
    self = [super initWithContent:nil];
    if (self) {
        _content = content;
        _selectionIndexPaths = [NSMutableArray array];
        _avoidsEmptySelection = YES;
        _preservesSelection = YES;
        _selectsInsertedObjects = YES;
        _alwaysUsesMultipleValuesMarker = NO;
    }
    return self;
}

- (instancetype)init { return [self initWithContent:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithContent:nil]; }

- (id)content { return _content; }
- (void)setContent:(id)content { _content = content; _root = nil; [self rearrangeObjects]; }

- (NSString *)childrenKeyPath { return _childrenKeyPath; }
- (void)setChildrenKeyPath:(NSString *)kp { _childrenKeyPath = [kp copy]; _root = nil; }
- (NSString *)countKeyPath { return _countKeyPath; }
- (void)setCountKeyPath:(NSString *)kp { _countKeyPath = [kp copy]; }
- (NSString *)leafKeyPath { return _leafKeyPath; }
- (void)setLeafKeyPath:(NSString *)kp { _leafKeyPath = [kp copy]; }
- (NSArray<NSSortDescriptor *> *)sortDescriptors { return _sortDescriptors; }
- (void)setSortDescriptors:(NSArray<NSSortDescriptor *> *)s { _sortDescriptors = [s copy]; _root = nil; [self rearrangeObjects]; }

/* --- tree building --- */

- (NSTreeNode *)_buildNodeForObject:(id)object
{
    NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:object];
    NSArray *children = nil;
    @try { children = [object valueForKeyPath:_childrenKeyPath]; }
    @catch (__unused NSException *e) { children = nil; }
    if ([children isKindOfClass:[NSArray class]]) {
        if (_sortDescriptors.count) children = [children sortedArrayUsingDescriptors:_sortDescriptors];
        for (id child in children)
            [[node mutableChildNodes] addObject:[self _buildNodeForObject:child]];
    }
    return node;
}

- (NSTreeNode *)arrangedObjects
{
    if (!_childrenKeyPath)
        [NSException raise:NSInternalInconsistencyException
                    format:@"<%@: %p>[object class: %@] Cannot perform operation because childrenKeyPath is nil",
                           NSStringFromClass([self class]), self,
                           _content ? NSStringFromClass([_content class]) : @"(null)"];
    if (!_root) [self rearrangeObjects];
    return _root;
}

- (void)rearrangeObjects
{
    if (!_childrenKeyPath) { _root = nil; return; }
    NSArray *previouslySelected = _preservesSelection ? [self selectedObjects] : nil;

    _root = [NSTreeNode treeNodeWithRepresentedObject:nil];  /* hidden root */
    NSArray *top;
    if ([_content isKindOfClass:[NSArray class]]) top = _content;
    else top = _content ? @[_content] : @[];
    if (_sortDescriptors.count) top = [top sortedArrayUsingDescriptors:_sortDescriptors];
    for (id obj in top)
        [[_root mutableChildNodes] addObject:[self _buildNodeForObject:obj]];

    if (_preservesSelection && previouslySelected.count) [self _reselectObjects:previouslySelected];
    [self _enforceSelectionInvariants];
}

/* --- selection --- */

- (NSArray<NSIndexPath *> *)selectionIndexPaths { return [_selectionIndexPaths copy]; }
- (NSIndexPath *)selectionIndexPath { return _selectionIndexPaths.firstObject; }

- (NSArray<NSTreeNode *> *)selectedNodes
{
    NSMutableArray *nodes = [NSMutableArray array];
    for (NSIndexPath *ip in _selectionIndexPaths) {
        NSTreeNode *n = [_root descendantNodeAtIndexPath:ip];
        if (n) [nodes addObject:n];
    }
    return nodes;
}

- (NSArray *)selectedObjects
{
    NSMutableArray *objs = [NSMutableArray array];
    for (NSTreeNode *n in [self selectedNodes])
        if (n.representedObject) [objs addObject:n.representedObject];
    return objs;
}

- (BOOL)setSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    _selectionIndexPaths = indexPaths ? [indexPaths mutableCopy] : [NSMutableArray array];
    [self _enforceSelectionInvariants];
    return YES;
}
- (BOOL)setSelectionIndexPath:(NSIndexPath *)indexPath
{
    return [self setSelectionIndexPaths:indexPath ? @[indexPath] : @[]];
}
- (BOOL)addSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    for (NSIndexPath *ip in indexPaths)
        if (![_selectionIndexPaths containsObject:ip]) [_selectionIndexPaths addObject:ip];
    [self _enforceSelectionInvariants];
    return YES;
}
- (BOOL)removeSelectionIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    [_selectionIndexPaths removeObjectsInArray:indexPaths];
    [self _enforceSelectionInvariants];
    return YES;
}

- (void)_reselectObjects:(NSArray *)objects
{
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    for (id obj in objects) {
        NSIndexPath *ip = [self _indexPathOfObject:obj underNode:_root];
        if (ip) [paths addObject:ip];
    }
    _selectionIndexPaths = paths;
}

- (NSIndexPath *)_indexPathOfObject:(id)object underNode:(NSTreeNode *)node
{
    NSArray *children = node.childNodes;
    for (NSTreeNode *child in children) {
        if (child.representedObject == object || [child.representedObject isEqual:object])
            return child.indexPath;
        NSIndexPath *deeper = [self _indexPathOfObject:object underNode:child];
        if (deeper) return deeper;
    }
    return nil;
}

- (void)_enforceSelectionInvariants
{
    NSMutableArray<NSIndexPath *> *valid = [NSMutableArray array];
    for (NSIndexPath *ip in _selectionIndexPaths)
        if ([_root descendantNodeAtIndexPath:ip]) [valid addObject:ip];
    _selectionIndexPaths = valid;
    if (_avoidsEmptySelection && _selectionIndexPaths.count == 0 && _root.childNodes.count > 0)
        [_selectionIndexPaths addObject:[NSIndexPath indexPathWithIndex:0]];
}

/* --- content mutation --- */

- (NSMutableArray *)_mutableChildrenOfRepresentedObject:(id)object
{
    id kids = [object valueForKeyPath:_childrenKeyPath];
    if ([kids isKindOfClass:[NSMutableArray class]]) return kids;
    NSMutableArray *m = kids ? [kids mutableCopy] : [NSMutableArray array];
    [object setValue:m forKeyPath:_childrenKeyPath];
    return m;
}

- (void)insertObject:(id)object atArrangedObjectIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger len = indexPath.length;
    if (len == 0) return;
    if (len == 1) {
        /* top-level insert into content */
        NSMutableArray *top = [_content isKindOfClass:[NSArray class]] ? [_content mutableCopy] : [NSMutableArray array];
        NSUInteger i = [indexPath indexAtPosition:0];
        if (i > top.count) i = top.count;
        [top insertObject:object atIndex:i];
        _content = top;
    } else {
        NSIndexPath *parentPath = [indexPath indexPathByRemovingLastIndex];
        NSTreeNode *parentNode = [_root descendantNodeAtIndexPath:parentPath];
        id parentObj = parentNode.representedObject;
        if (!parentObj) return;
        NSMutableArray *kids = [self _mutableChildrenOfRepresentedObject:parentObj];
        NSUInteger i = [indexPath indexAtPosition:len - 1];
        if (i > kids.count) i = kids.count;
        [kids insertObject:object atIndex:i];
    }
    [self rearrangeObjects];
    if (_selectsInsertedObjects) [self _reselectObjects:@[object]];
    [self _enforceSelectionInvariants];
}

- (void)removeObjectAtArrangedObjectIndexPath:(NSIndexPath *)indexPath
{
    NSTreeNode *node = [_root descendantNodeAtIndexPath:indexPath];
    if (!node) return;
    id obj = node.representedObject;
    NSUInteger len = indexPath.length;
    if (len == 1) {
        NSMutableArray *top = [_content isKindOfClass:[NSArray class]] ? [_content mutableCopy] : [NSMutableArray array];
        [top removeObject:obj];
        _content = top;
    } else {
        NSTreeNode *parentNode = [_root descendantNodeAtIndexPath:[indexPath indexPathByRemovingLastIndex]];
        id parentObj = parentNode.representedObject;
        if (parentObj) [[self _mutableChildrenOfRepresentedObject:parentObj] removeObject:obj];
    }
    [self rearrangeObjects];
    [self _enforceSelectionInvariants];
}

/* --- new objects --- */

- (id)newObject { Class c = self.objectClass ?: [NSMutableDictionary class]; return [[c alloc] init]; }
- (id)newChildObject { return [self newObject]; }

/* --- actions / gating --- */

- (BOOL)canInsert { return self.isEditable; }
- (BOOL)canAdd { return self.isEditable; }
- (BOOL)canInsertChild { return self.isEditable && _selectionIndexPaths.count > 0; }
- (BOOL)canAddChild { return self.isEditable && _selectionIndexPaths.count > 0; }
- (BOOL)canRemove { return self.isEditable && _selectionIndexPaths.count > 0; }

- (void)insert:(id)sender
{
    if (!self.canInsert) return;
    NSIndexPath *ip = self.selectionIndexPath ?: [NSIndexPath indexPathWithIndex:(_root.childNodes.count)];
    [self insertObject:[self newObject] atArrangedObjectIndexPath:ip];
}
- (void)add:(id)sender
{
    if (!self.canAdd) return;
    [self insertObject:[self newObject] atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:_root.childNodes.count]];
}
- (void)addChild:(id)sender
{
    if (!self.canAddChild) return;
    NSIndexPath *sel = self.selectionIndexPath; if (!sel) return;
    NSTreeNode *parent = [_root descendantNodeAtIndexPath:sel];
    NSIndexPath *childPath = [sel indexPathByAddingIndex:parent.childNodes.count];
    [self insertObject:[self newChildObject] atArrangedObjectIndexPath:childPath];
}
- (void)remove:(id)sender
{
    if (!self.canRemove) return;
    /* remove deepest-first so earlier index paths stay valid */
    NSArray *paths = [_selectionIndexPaths sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
        return [b compare:a];
    }];
    for (NSIndexPath *ip in paths) [self removeObjectAtArrangedObjectIndexPath:ip];
}

/* --- flags --- */

#define TC_BOOL(getter, setter, ivar) \
    - (BOOL)getter { return ivar; } \
    - (void)setter:(BOOL)v { ivar = v; }
TC_BOOL(avoidsEmptySelection, setAvoidsEmptySelection, _avoidsEmptySelection)
TC_BOOL(preservesSelection, setPreservesSelection, _preservesSelection)
TC_BOOL(selectsInsertedObjects, setSelectsInsertedObjects, _selectsInsertedObjects)
TC_BOOL(alwaysUsesMultipleValuesMarker, setAlwaysUsesMultipleValuesMarker, _alwaysUsesMultipleValuesMarker)

@end

/*
 * NSTreeNode.m — 1:1 (core). See NSTreeNode.h for the interface evidence.
 *
 * _childNodes is the backing store; mutableChildNodes returns a concrete
 * NSMutableArray subclass (_NSTreeNodeChildArray) that proxies to it and sets/
 * clears each child's _parentNode on insert/remove — AppKit's KVO child proxy.
 * indexPath is built by walking up parentNode collecting child indices;
 * descendantNodeAtIndexPath: walks down. isLeaf is childNodes.count == 0.
 */
#import "NSTreeNode.h"

@interface NSTreeNode ()
@property (nullable, weak, readwrite) NSTreeNode *parentNode;
- (NSMutableArray<NSTreeNode *> *)_backingChildren;
@end

/* A mutable-array proxy over a node's children that maintains parentNode. */
@interface _NSTreeNodeChildArray : NSMutableArray
@end
@implementation _NSTreeNodeChildArray {
    NSTreeNode *_owner;          /* weak-like; owner outlives the proxy */
    NSMutableArray *_backing;
}
- (instancetype)initWithOwner:(NSTreeNode *)owner backing:(NSMutableArray *)backing
{
    if ((self = [super init])) { _owner = owner; _backing = backing; }
    return self;
}
- (NSUInteger)count { return _backing.count; }
- (id)objectAtIndex:(NSUInteger)index { return _backing[index]; }
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
    [_backing insertObject:anObject atIndex:index];
    [(NSTreeNode *)anObject setParentNode:_owner];
}
- (void)removeObjectAtIndex:(NSUInteger)index
{
    NSTreeNode *n = _backing[index];
    if (n.parentNode == _owner) [n setParentNode:nil];
    [_backing removeObjectAtIndex:index];
}
- (void)addObject:(id)anObject { [self insertObject:anObject atIndex:_backing.count]; }
- (void)removeLastObject { if (_backing.count) [self removeObjectAtIndex:_backing.count - 1]; }
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject
{
    NSTreeNode *old = _backing[index];
    if (old.parentNode == _owner) [old setParentNode:nil];
    _backing[index] = anObject;
    [(NSTreeNode *)anObject setParentNode:_owner];
}
@end


@implementation NSTreeNode {
    id _representedObject;
    NSMutableArray<NSTreeNode *> *_childNodes;
}
@synthesize parentNode = _parentNode;

- (instancetype)initWithRepresentedObject:(id)modelObject
{
    self = [super init];
    if (self) { _representedObject = modelObject; _childNodes = [NSMutableArray array]; }
    return self;
}

+ (instancetype)treeNodeWithRepresentedObject:(id)modelObject
{
    return [[self alloc] initWithRepresentedObject:modelObject];
}

- (id)representedObject { return _representedObject; }
- (NSMutableArray<NSTreeNode *> *)_backingChildren { return _childNodes; }
- (NSArray<NSTreeNode *> *)childNodes { return [_childNodes copy]; }
- (NSMutableArray<NSTreeNode *> *)mutableChildNodes
{
    return [[_NSTreeNodeChildArray alloc] initWithOwner:self backing:_childNodes];
}
- (BOOL)isLeaf { return _childNodes.count == 0; }

- (NSIndexPath *)indexPath
{
    NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
    NSTreeNode *node = self, *parent = self.parentNode;
    while (parent) {
        NSUInteger idx = [parent->_childNodes indexOfObjectIdenticalTo:node];
        [indices insertObject:@(idx) atIndex:0];
        node = parent;
        parent = parent.parentNode;
    }
    NSIndexPath *path = nil;
    for (NSNumber *n in indices) {
        path = path ? [path indexPathByAddingIndex:n.unsignedIntegerValue]
                    : [NSIndexPath indexPathWithIndex:n.unsignedIntegerValue];
    }
    return path ?: [[NSIndexPath alloc] init];
}

- (NSTreeNode *)descendantNodeAtIndexPath:(NSIndexPath *)indexPath
{
    NSTreeNode *node = self;
    for (NSUInteger i = 0; i < indexPath.length; i++) {
        NSUInteger idx = [indexPath indexAtPosition:i];
        if (idx >= node->_childNodes.count) return nil;
        node = node->_childNodes[idx];
    }
    return node;
}

@end

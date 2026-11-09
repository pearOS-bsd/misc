/*
 * NSTreeNode.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTreeNode : NSObject {
 *       @ _childNodesProxy;  @ _representedObject;
 *       @"NSMutableArray" _childNodes;  @"NSTreeNode" _parentNode;
 *   }
 *   @property (T@,R) representedObject;  (T@"NSIndexPath",R) indexPath;
 *   @property (TB,R,GisLeaf) leaf;  (T@"NSArray",R,C) childNodes;
 *   @property (T@"NSMutableArray",R) mutableChildNodes;
 *   +treeNodeWithRepresentedObject: -initWithRepresentedObject:
 *   -parentNode -descendantNodeAtIndexPath:
 *
 * A node in a tree model. mutableChildNodes returns a KVO-compliant proxy that
 * maintains each child's parentNode as items are added/removed; indexPath walks
 * up through parentNode, descendantNodeAtIndexPath: walks down. NSTreeController
 * binding/sorting is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTreeNode : NSObject

+ (instancetype)treeNodeWithRepresentedObject:(nullable id)modelObject;
- (instancetype)initWithRepresentedObject:(nullable id)modelObject;

@property (readonly, nullable, strong) id representedObject;
@property (readonly, nullable, weak) NSTreeNode *parentNode;
@property (readonly, copy) NSArray<NSTreeNode *> *childNodes;
@property (readonly, strong) NSMutableArray<NSTreeNode *> *mutableChildNodes;
@property (readonly, getter=isLeaf) BOOL leaf;
@property (readonly) NSIndexPath *indexPath;

- (nullable NSTreeNode *)descendantNodeAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

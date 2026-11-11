/*
 * NSObjectController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSObjectController (: NSController), the single-object bindings controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSObjectController_interface.txt. Real ivars: _content,
 * _objectClassName/_objectClass, _contentObjectArray, and a packed
 * _objectControllerFlags (editable/automaticallyPreparesContent/… bits).
 *
 * Defaults MEASURED on this Mac: editable=YES, automaticallyPreparesContent=NO,
 * objectClass=NSMutableDictionary, content=nil, canAdd=YES, canRemove=NO,
 * newObject makes an NSMutableDictionary; initWithContent: gives canRemove=YES
 * and selectedObjects.count==1.
 *
 * This core reproduces the non-CoreData content model: content/setContent:,
 * newObject/prepareContent, add:/remove: (+ addObject:/removeObject:),
 * editable, automaticallyPreparesContent, canAdd/canRemove, selectedObjects and
 * a KVC selection proxy. The CoreData path (managedObjectContext/entityName/
 * fetchPredicate/fetch:) and the full KVO binding adaptor are TODO(stage2).
 */

#import "NSController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObjectController : NSController

- (instancetype)initWithContent:(nullable id)content;

@property (nullable, strong) id content;
@property (readonly, strong) id selection;
@property (readonly, copy) NSArray *selectedObjects;

@property (getter=isEditable) BOOL editable;          /* default YES */
@property BOOL automaticallyPreparesContent;          /* default NO */
@property (assign) Class objectClass;                 /* default NSMutableDictionary */

@property (readonly) BOOL canAdd;
@property (readonly) BOOL canRemove;

- (id)newObject;
- (void)prepareContent;
- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (void)add:(nullable id)sender;
- (void)remove:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

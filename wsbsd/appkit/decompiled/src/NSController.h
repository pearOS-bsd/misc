/*
 * NSController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSController, the abstract base of the Cocoa Bindings controller family
 * (NSObjectController / NSArrayController / NSTreeController / NSUserDefaultsController).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSController_interface.txt. It conforms to <NSEditor, NSEditorRegistration>
 * and keeps an _editors array plus an _isEditing bit inside a packed
 * _bindingsControllerFlags field.
 *
 * This core reproduces the observable editor-registration state machine:
 * objectDidBeginEditing:/objectDidEndEditing: track registered editors,
 * isEditing reflects whether any are outstanding, and commitEditing/
 * discardEditing drive each registered editor and clear the set. The KVO
 * binding adaptor, declared/dependent model-key tables, model observation and
 * the single-value accessor machinery are TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* NSEditor / NSEditorRegistration as AppKit declares them. */
@protocol NSEditor <NSObject>
- (void)discardEditing;
- (BOOL)commitEditing;
- (void)commitEditingWithDelegate:(nullable id)delegate didCommitSelector:(nullable SEL)didCommitSelector contextInfo:(nullable void *)contextInfo;
- (BOOL)commitEditingAndReturnError:(NSError * _Nullable * _Nullable)error;
@end

@protocol NSEditorRegistration <NSObject>
- (void)objectDidBeginEditing:(id<NSEditor>)editor;
- (void)objectDidEndEditing:(id<NSEditor>)editor;
@end

@interface NSController : NSObject <NSCoding, NSEditor, NSEditorRegistration> {
    NSMutableArray *_editors;
    BOOL _isEditing;
    BOOL _alwaysPresentsApplicationModalAlerts;
}

@property (getter=isEditing, readonly) BOOL editing;
@property BOOL alwaysPresentsApplicationModalAlerts;

/* NSEditorRegistration */
- (void)objectDidBeginEditing:(id<NSEditor>)editor;
- (void)objectDidEndEditing:(id<NSEditor>)editor;

/* NSEditor */
- (BOOL)commitEditing;
- (BOOL)commitEditingAndReturnError:(NSError * _Nullable * _Nullable)error;
- (void)commitEditingWithDelegate:(nullable id)delegate didCommitSelector:(nullable SEL)didCommitSelector contextInfo:(nullable void *)contextInfo;
- (void)discardEditing;

@end

NS_ASSUME_NONNULL_END

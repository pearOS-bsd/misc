/*
 * NSPredicateEditor.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPredicateEditor, the NSRuleEditor whose rows come from
 * NSPredicateEditorRowTemplates.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPredicateEditor_interface.txt.
 *
 * NSPredicateEditor is an NSRuleEditor (measured). This core adds the
 * rowTemplates property, defaulting to a single auto-created compound template
 * (measured). Building the NSPredicate from the row values is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSRuleEditor.h"
#import "NSPredicateEditorRowTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPredicateEditor : NSRuleEditor

@property (copy) NSArray<NSPredicateEditorRowTemplate *> *rowTemplates;

@end

NS_ASSUME_NONNULL_END

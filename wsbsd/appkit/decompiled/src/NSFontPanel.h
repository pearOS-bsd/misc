/*
 * NSFontPanel.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSFontPanel, the shared system font picker panel.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSFontPanel_interface.txt.
 *
 * NSFontPanel is an NSPanel (measured). This core reproduces the shared
 * singleton and the state surface: accessoryView, worksWhenModal (YES),
 * enabled (YES), and setPanelFont:isMultiple: (records the current selection
 * and whether it is a multiple selection). The font-conversion UI
 * (panelConvertFont:, reloadDefaultFontFamilies) is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSPanel.h"

NS_ASSUME_NONNULL_BEGIN

@class NSFont, NSView;

@interface NSFontPanel : NSPanel

@property (class, readonly, strong) NSFontPanel *sharedFontPanel;
@property (class, readonly) BOOL sharedFontPanelExists;

@property (nullable, strong) NSView *accessoryView;
@property BOOL worksWhenModal;
@property (getter=isEnabled) BOOL enabled;

- (void)setPanelFont:(NSFont *)fontObj isMultiple:(BOOL)flag;
- (nullable NSFont *)panelConvertFont:(NSFont *)fontObj;

@end

NS_ASSUME_NONNULL_END

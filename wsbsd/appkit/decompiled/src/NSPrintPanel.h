/*
 * NSPrintPanel.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPrintPanel, the Print dialog controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPrintPanel_interface.txt.
 *
 * This core reproduces the configuration surface: +printPanel, options
 * (default ShowsCopies|ShowsPageRange — measured), jobStyleHint / helpAnchor
 * (nil), defaultButtonTitle, and the accessory-controller list
 * (accessoryControllers / addAccessoryController:). The actual modal/sheet run
 * (beginSheetWithPrintInfo:…, runModalWithPrintInfo:) and the live printInfo are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSPrintInfo.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSPrintPanelOptions) {
    NSPrintPanelShowsCopies = 1 << 0,
    NSPrintPanelShowsPageRange = 1 << 1,
    NSPrintPanelShowsPaperSize = 1 << 2,
    NSPrintPanelShowsOrientation = 1 << 3,
    NSPrintPanelShowsScaling = 1 << 4,
    NSPrintPanelShowsPrintSelection = 1 << 5,
    NSPrintPanelShowsPageSetupAccessory = 1 << 8,
    NSPrintPanelShowsPreview = 1 << 17,
};

@interface NSPrintPanel : NSObject

+ (instancetype)printPanel;

- (void)addAccessoryController:(id)accessoryController;
- (void)removeAccessoryController:(id)accessoryController;
@property (readonly, copy) NSArray *accessoryControllers;

@property NSPrintPanelOptions options;
@property (nullable, copy) NSString *defaultButtonTitle;
@property (nullable, copy) NSString *helpAnchor;
@property (copy) NSString *jobStyleHint;
@property (readonly, nullable) NSPrintInfo *printInfo;

@end

NS_ASSUME_NONNULL_END

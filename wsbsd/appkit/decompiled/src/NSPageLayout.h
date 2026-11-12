/*
 * NSPageLayout.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPageLayout, the Page Setup dialog controller.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPageLayout_interface.txt.
 *
 * This core reproduces +pageLayout and the accessory-controller list; the modal/
 * sheet run (beginSheetWithPrintInfo:…, runModalWithPrintInfo:) and the live
 * printInfo are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSPrintInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPageLayout : NSObject

+ (instancetype)pageLayout;

- (void)addAccessoryController:(id)accessoryController;
- (void)removeAccessoryController:(id)accessoryController;
@property (readonly, copy) NSArray *accessoryControllers;
@property (readonly, nullable) NSPrintInfo *printInfo;

@end

NS_ASSUME_NONNULL_END

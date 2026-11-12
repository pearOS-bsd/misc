/*
 * NSPrintOperation.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPrintOperation, which drives a print or PDF job for a view.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPrintOperation_interface.txt.
 *
 * This core reproduces the configuration + current-operation model:
 * +printOperationWithView:[printInfo:] (printInfo defaults to a copy of the
 * shared info — measured), +currentOperation/+setCurrentOperation: (thread-local,
 * nil outside a run — measured), jobTitle (nil), showsPrintPanel (YES),
 * showsProgressPanel (YES), canSpawnSeparateThread (NO), pageOrder (Ascending),
 * view, printInfo, isCopyingOperation (NO). The actual printing run
 * (-runOperation…, pagination, the graphics context) is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSPrintInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class NSView, NSPrintPanel;

typedef NS_ENUM(NSInteger, NSPrintingPageOrder) {
    NSDescendingPageOrder = -1,
    NSSpecialPageOrder = 0,
    NSAscendingPageOrder = 1,
    NSUnknownPageOrder = 2,
};

@interface NSPrintOperation : NSObject

+ (instancetype)printOperationWithView:(NSView *)view;
+ (instancetype)printOperationWithView:(NSView *)view printInfo:(NSPrintInfo *)printInfo;
@property (class, nullable, strong) NSPrintOperation *currentOperation;

@property (nullable, copy) NSString *jobTitle;
@property BOOL showsPrintPanel;
@property BOOL showsProgressPanel;
@property BOOL canSpawnSeparateThread;
@property NSPrintingPageOrder pageOrder;
@property (readonly) NSView *view;
@property (copy) NSPrintInfo *printInfo;
@property (readonly, getter=isCopyingOperation) BOOL copyingOperation;

@end

NS_ASSUME_NONNULL_END

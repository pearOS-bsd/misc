/* <Quartz/Quartz.h>: on Apple the umbrella of QuartzCore, ImageKit, PDFKit, QuickLookUI and QuartzFilters. Here AppKit, the Core Animation names (QuartzCore/QuartzCore.h) and the QuickLook preview panel (sdk/src/QuickLook.m). */
#ifndef WSBSD_QUARTZ_H
#define WSBSD_QUARTZ_H
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
@protocol QLPreviewItem <NSObject>
@property (readonly) NSURL *previewItemURL;
@optional
@property (readonly) NSString *previewItemTitle;
@end
@class QLPreviewPanel;
@protocol QLPreviewPanelDataSource <NSObject>
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel;
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index;
@end
@protocol QLPreviewPanelDelegate <NSObject>
@optional
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event;
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id<QLPreviewItem>)item;
@end
@interface QLPreviewPanel : NSPanel
@property (assign) id<QLPreviewPanelDataSource> dataSource;
@property (assign) id delegate;
@property NSInteger currentPreviewItemIndex;
+ (QLPreviewPanel *)sharedPreviewPanel;
+ (BOOL)sharedPreviewPanelExists;
@property (readonly) id<QLPreviewItem> currentPreviewItem;
@property (readonly) id currentController;
- (void)reloadData;
- (void)refreshCurrentPreviewItem;
@end
@interface NSObject (QLPreviewPanelController)
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel;
@end
#endif

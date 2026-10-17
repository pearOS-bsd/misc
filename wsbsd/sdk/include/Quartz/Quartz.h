/* <Quartz/Quartz.h>: on Apple the umbrella of QuartzCore, ImageKit, PDFKit, QuickLookUI and QuartzFilters. Here AppKit, the Core Animation names (QuartzCore/QuartzCore.h) and a QuickLook panel
 * that does not preview anything (the preview window never appears; an application asking for it is told it is not available). */
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
@property (assign) id<QLPreviewPanelDelegate> delegate;
@property NSInteger currentPreviewItemIndex;
+ (QLPreviewPanel *)sharedPreviewPanel;
+ (BOOL)sharedPreviewPanelExists;
- (void)reloadData;
- (void)refreshCurrentPreviewItem;
@end
@interface NSObject (QLPreviewPanelController)
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel;
@end
#endif

/* Opens the QuickLook panel on the files given as arguments (arrows switch, space / Esc close): ql_demo FILE... */
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
@interface Item : NSObject <QLPreviewItem> { @public NSURL *u; } @end
@implementation Item - (NSURL *)previewItemURL { return u; } @end
@interface Src : NSObject <QLPreviewPanelDataSource> { @public NSArray *items; } @end
@implementation Src
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)p { return [items count]; }
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)p previewItemAtIndex:(NSInteger)i { return items[i]; }
@end
int main(int argc, char **argv)
{
	@autoreleasepool {
		[NSApplication sharedApplication]; Src *s = [Src new]; NSMutableArray *a = [NSMutableArray array];
		for (int i = 1; i < argc; i++) { Item *it = [Item new]; it->u = [NSURL fileURLWithPath: [NSString stringWithUTF8String: argv[i]]]; [a addObject: it]; }
		s->items = a; QLPreviewPanel *p = [QLPreviewPanel sharedPreviewPanel]; p.dataSource = s; [p setFrameOrigin: NSMakePoint(200, 150)]; [p makeKeyAndOrderFront: nil];
		[NSApp run];
	}
	return 0;
}

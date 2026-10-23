/* Files dragged from one program and dropped in a window of another. The window server has no drag session between processes, so the program the drag ends in finds the window under the pointer (the list of windows
 * front to back, their bounds, their owner) and posts the dropped paths to the owner's connection as notifications (type WDND, a header line and up to a few paths each); the owner turns them into the
 * drag events GNUstep's windows understand (Enter, Update, Drop) with a drag pasteboard of NSFilenamesPboardType and an NSDraggingInfo of its own. Drags inside one program stay with GSDragView. */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import <GNUstepGUI/GSDragView.h>
#import <objc/runtime.h>
#include "wsd/WsdServer.h"
#include "wsd/WsdMacTheme.h"
#include "ws_client.h"

#define WDND 0x574e4457u                                       /* the notification type */
static NSMutableDictionary *gChunks;

@interface WsdDragInfo : NSObject <NSDraggingInfo> { @public NSWindow *window; NSPoint loc; NSPasteboard *pb; NSInteger seq; } @end
@implementation WsdDragInfo
- (NSWindow *)draggingDestinationWindow { return window; }
- (NSPoint)draggingLocation { return loc; }
- (NSPasteboard *)draggingPasteboard { return pb; }
- (NSInteger)draggingSequenceNumber { return seq; }
- (id)draggingSource { return nil; }
- (NSDragOperation)draggingSourceOperationMask { return NSDragOperationCopy | NSDragOperationGeneric | NSDragOperationLink; }
- (NSImage *)draggedImage { return nil; }
- (NSPoint)draggedImageLocation { return loc; }
- (void)slideDraggedImageTo:(NSPoint)p {}
- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)u { return nil; }
- (void)postDragEvent:(NSEvent *)e {}
@end
static WsdDragInfo *gInfo;

@interface WsdServer (WsdDrop)
- (void) wsdHandleDropNotifications;
- (BOOL) wsdDropFiles: (NSArray *)paths atScreenPoint: (NSPoint)p;
@end

@implementation WsdServer (WsdDrop)
- (id <NSDraggingInfo>) dragInfo
{
	GSDragView *g = [GSDragView sharedDragView]; if ([g isDragging]) return g; if (!gInfo) gInfo = [WsdDragInfo new]; return gInfo;
}
/* the sender: the topmost window at the point (a point of the screen, origin bottom left) belongs to another program: tell that program */
- (BOOL) wsdDropFiles: (NSArray *)paths atScreenPoint: (NSPoint)p
{
	if (getenv("WSD_DND_DEBUG")) NSLog(@"WDND send %@ at %@", paths, NSStringFromPoint(p));
	if (![paths count]) return NO; int sh = [self boundsForScreen: 0].size.height; int px = (int)p.x, py = sh - (int)p.y; uint32_t list[256]; int total = 0;
	if (ws_win_list(conn, 0, 1, list, 256, &total) != 0) return NO;
	for (int i = 0; i < total && i < 256; i++) {
		ws_win w = { list[i], NULL }; ws_rect r; if (ws_win_get_bounds(conn, &w, &r) != 0) continue; if (r.w < 40 || r.h < 40) continue; if (px < r.x || px >= r.x + r.w || py < r.y || py >= r.y + r.h) continue;
		int owner = 0, rights = 0; if (ws_win_get_owner(conn, &w, &owner, &rights) != 0) continue; if (getenv("WSD_DND_DEBUG")) NSLog(@"WDND hit window %u owner %d (me %d)", list[i], owner, (int)ws_conn_id(conn)); if (owner == ws_conn_id(conn)) return NO;                                          /* a window of this program: the program handles it itself */
		int level = 0; ws_win_get_level(conn, &w, &level); if (level > 20) continue;                                                                                                                    /* the menu bar and pop-ups do not take drops */
		/* the paths in chunks of about 600 bytes */
		NSMutableArray *chunks = [NSMutableArray array], *cur = [NSMutableArray array]; NSUInteger sz = 0; for (NSString *s in paths) { NSUInteger l = [s lengthOfBytesUsingEncoding: NSUTF8StringEncoding] + 1; if (sz + l > 600 && [cur count]) { [chunks addObject: cur]; cur = [NSMutableArray array]; sz = 0; } [cur addObject: s]; sz += l; } if ([cur count]) [chunks addObject: cur];
		static int seq; seq++; for (NSUInteger k = 0; k < [chunks count]; k++) {
			NSString *msg = [NSString stringWithFormat: @"WDND1 %d %lu %lu %u %d %d\n%@", seq, (unsigned long)k, (unsigned long)[chunks count], list[i], px - r.x, py - r.y, [chunks[k] componentsJoinedByString: @"\n"]]; NSData *d = [msg dataUsingEncoding: NSUTF8StringEncoding];
			ws_notification_post(conn, (uint32_t)owner, WDND, [d bytes], (uint32_t)MIN([d length], 760)); }
		return YES;
	}
	return NO;
}
/* the receiver */
- (void) wsdDeliverDrop: (NSArray *)paths toWindowNumber: (uint32_t)wid at: (NSPoint)lp
{
	struct wsd_window *w = [self wsdWindow: (int)wid]; if (!w) return; NSWindow *nw = GSWindowWithNumber(w->number); if (!nw) return;
	NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard]; [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: nil]; [pb setPropertyList: paths forType: NSFilenamesPboardType];
	if (!gInfo) gInfo = [WsdDragInfo new]; gInfo->window = nw; gInfo->pb = pb; gInfo->loc = NSMakePoint(lp.x, w->h - lp.y); gInfo->seq++;
	for (int step = 0; step < 3; step++) {
		NSEvent *e = [NSEvent otherEventWithType: NSAppKitDefined location: gInfo->loc modifierFlags: 0 timestamp: 0 windowNumber: [nw windowNumber] context: GSCurrentContext() subtype: step == 0 ? GSAppKitDraggingEnter : step == 1 ? GSAppKitDraggingUpdate : GSAppKitDraggingDrop data1: 0 data2: NSDragOperationCopy];
		[nw sendEvent: e];
	}
}
- (void) wsdHandleDropNotifications
{
	uint32_t type; uint8_t data[1024]; uint32_t len;
	while (ws_conn_next_notification(conn, 0, &type, data, &len)) {
		if (getenv("WSD_DND_DEBUG")) NSLog(@"WDND notification type %u len %u", type, len);
		if (type != WDND) continue; NSString *msg = [[[NSString alloc] initWithBytes: data length: len encoding: NSUTF8StringEncoding] autorelease]; NSRange nl = [msg rangeOfString: @"\n"]; if (nl.location == NSNotFound) continue;
		NSArray *h = [[msg substringToIndex: nl.location] componentsSeparatedByString: @" "]; if ([h count] < 7 || ![h[0] isEqual: @"WDND1"]) continue; NSArray *ps = [[msg substringFromIndex: nl.location + 1] componentsSeparatedByString: @"\n"];
		if (!gChunks) gChunks = [[NSMutableDictionary alloc] init]; NSString *key = h[1]; NSMutableDictionary *st = gChunks[key]; if (!st) { st = [NSMutableDictionary dictionaryWithObjectsAndKeys: [NSMutableArray array], @"paths", [NSNumber numberWithInt: 0], @"got", nil]; gChunks[key] = st; }
		[st[@"paths"] addObjectsFromArray: ps]; st[@"got"] = [NSNumber numberWithInt: [st[@"got"] intValue] + 1];
		if ([st[@"got"] intValue] >= [h[3] intValue]) { NSArray *all = [[st[@"paths"] copy] autorelease]; [gChunks removeObjectForKey: key]; [self wsdDeliverDrop: all toWindowNumber: (uint32_t)[h[4] longLongValue] at: NSMakePoint([h[5] intValue], [h[6] intValue])]; }
	}
}
@end

/* the pump of events also looks for drops */
static IMP origReceived;
static void wsdReceivedWithDrops(id self, SEL _cmd, void *data, int type, void *extra, NSString *mode)
{
	((void (*)(id, SEL, void *, int, void *, NSString *))origReceived)(self, _cmd, data, type, extra, mode);
	[(WsdServer *)self wsdHandleDropNotifications];
}
void WsdInstallDragDrop(void)
{
	if (origReceived) return; Method m = class_getInstanceMethod([WsdServer class], @selector(receivedEvent:type:extra:forMode:)); if (m) origReceived = method_setImplementation(m, (IMP)wsdReceivedWithDrops);
}

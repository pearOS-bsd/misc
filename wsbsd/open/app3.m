// controls a typical app uses: table view with a data source, split view, pop-up, slider, check box, progress, tab view
#import <Cocoa/Cocoa.h>
@interface D : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate> { NSWindow *w; } @end
@implementation D
- (void)alert:(id)s { NSAlert *a = [NSAlert new]; [a setMessageText:@"Delete file?"]; [a setInformativeText:@"This cannot be undone."]; [a addButtonWithTitle:@"Delete"]; [a addButtonWithTitle:@"Cancel"]; NSInteger r = [a runModal]; NSLog(@"app3: alert returned %ld", (long)r); }
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { return 5; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r { return [NSString stringWithFormat:@"row %ld", (long)r]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n {
  w = [[NSWindow alloc] initWithContentRect:NSMakeRect(300, 300, 600, 400) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
  [w setTitle:@"app3"];
  NSView *cv = [w contentView];
  NSSplitView *sp = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 100, 600, 300)]; [sp setVertical:YES];
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300)];
  NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300)];
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"a"]; [col setWidth:180]; [tv addTableColumn:col]; [tv setDataSource:self]; [tv setDelegate:self];
  [sv setDocumentView:tv]; [sp addSubview:sv];
  NSView *right = [[NSView alloc] initWithFrame:NSMakeRect(200, 0, 400, 300)]; [sp addSubview:right];
  [cv addSubview:sp];
  NSPopUpButton *pb = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(10, 60, 140, 26) pullsDown:NO]; [pb addItemsWithTitles:@[@"One", @"Two", @"Three"]]; [cv addSubview:pb];
  NSSlider *sl = [NSSlider sliderWithValue:30 minValue:0 maxValue:100 target:nil action:nil]; [sl setFrame:NSMakeRect(160, 60, 200, 26)]; [cv addSubview:sl];
  NSButton *cb = [NSButton checkboxWithTitle:@"Check" target:nil action:nil]; [cb setFrame:NSMakeRect(370, 60, 100, 26)]; [cv addSubview:cb];
  NSProgressIndicator *pi = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(10, 20, 300, 16)]; [pi setIndeterminate:NO]; [pi setDoubleValue:40]; [cv addSubview:pi];
  { NSButton *ab = [NSButton buttonWithTitle:@"Alert" target:self action:@selector(alert:)]; [ab setFrame:NSMakeRect(480, 56, 100, 32)]; [cv addSubview:ab]; }
  [w makeKeyAndOrderFront:nil]; NSLog(@"app3: up");
}
@end
int main(void) { @autoreleasepool { NSApplication *a = [NSApplication sharedApplication]; D *d = [D new]; [a setDelegate:d]; [a run]; } return 0; }

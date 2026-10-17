/* Port of ChooseStringEncodingWindowController.swift */
#import "Hex_Fiend-Swift.h"
#import "AppDelegate.h"

@interface HFEncodingChoice : NSObject
@property (copy) NSString *label;
@property HFNSStringEncoding *encoding;
@end
@implementation HFEncodingChoice @end

@implementation ChooseStringEncodingWindowController {
	IBOutlet __weak NSTableView *tableView;
	IBOutlet __weak NSSearchField *searchField;
	NSArray<HFEncodingChoice *> *encodings;
	NSArray<HFEncodingChoice *> *activeEncodings;
	NSArray<NSNumber *> *menuEncodings;
}

- (NSString *)windowNibName { return @"ChooseStringEncodingDialog"; }
- (instancetype)init { return [super initWithWindow: nil]; }

- (void)populateStringEncodings
{
	NSMutableArray *list = [NSMutableArray array];
	for (HFNSStringEncoding *e in [HFEncodingManager shared].systemEncodings) {
		HFEncodingChoice *c = [[HFEncodingChoice alloc] init];
		c.label = [e.name isEqualToString: e.identifier] ? e.name : [NSString stringWithFormat: @"%@ (%@)", e.name, e.identifier];
		c.encoding = e; [list addObject: c];
	}
	[list sortUsingComparator: ^NSComparisonResult(HFEncodingChoice *a, HFEncodingChoice *b) { return [a.label compare: b.label]; }];
	encodings = list; activeEncodings = list;
	menuEncodings = AppDelegate.shared.encodings.menuSystemEncodingsNumbers;
	[tableView reloadData];
}

- (void)windowDidLoad { [super windowDidLoad]; [self populateStringEncodings]; }

- (void)controlTextDidChange: (NSNotification *)obj
{
	NSString *text = [searchField stringValue];
	if (text.length > 0) {
		NSMutableArray *r = [NSMutableArray array];
		for (HFEncodingChoice *c in encodings)
			if ([c.encoding.name localizedCaseInsensitiveContainsString: text] || [c.encoding.identifier localizedCaseInsensitiveContainsString: text]) [r addObject: c];
		activeEncodings = r;
	} else activeEncodings = encodings;
	[tableView reloadData];
}

- (void)reload { [tableView reloadData]; }

- (NSInteger)numberOfRowsInTableView: (NSTableView *)tv { return (NSInteger)activeEncodings.count; }

- (id)tableView: (NSTableView *)tv objectValueForTableColumn: (NSTableColumn *)col row: (NSInteger)row
{
	NSString *ident = [col identifier]; HFNSStringEncoding *e = activeEncodings[(NSUInteger)row].encoding;
	if ([ident isEqualToString: @"name"]) return e.name;
	if ([ident isEqualToString: @"identifier"]) return e.identifier;
	if ([ident isEqualToString: @"show"]) return [menuEncodings containsObject: @(e.encoding)] ? @(NSControlStateValueOn) : @(NSControlStateValueOff);
	return nil;
}

- (void)tableView: (NSTableView *)tv setObjectValue: (id)object forTableColumn: (NSTableColumn *)col row: (NSInteger)row
{
	if (![[col identifier] isEqualToString: @"show"] || ![object isKindOfClass: [NSNumber class]]) return;
	NSNumber *number = @(activeEncodings[(NSUInteger)row].encoding.encoding);
	NSMutableArray *m = [menuEncodings mutableCopy]; [m removeObject: number];
	if ([object boolValue]) [m addObject: number];
	menuEncodings = m;
	AppDelegate.shared.encodings.menuSystemEncodingsNumbers = menuEncodings;
}

- (void)tableView: (NSTableView *)tv willDisplayCell: (id)cell forTableColumn: (NSTableColumn *)col row: (NSInteger)row
{
	if (![[col identifier] isEqualToString: @"show"] || ![cell isKindOfClass: [NSButtonCell class]]) return;
	[(NSButtonCell *)cell setEnabled: ![activeEncodings[(NSUInteger)row].encoding.identifier isEqualToString: AppDelegate.shared.defaultStringEncoding.identifier]];
}
@end

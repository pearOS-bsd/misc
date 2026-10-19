/* NSTextView additions: scrollable constructors, smart quotes / dashes while typing, characterIndexForInsertionAtPoint:, toggles. */
#import <AppKit/AppKit.h>
@interface NSTextView (D) + (NSScrollView *)scrollableTextView; + (NSScrollView *)scrollablePlainDocumentContentTextView; + (NSTextView *)fieldEditor;
- (BOOL)isAutomaticQuoteSubstitutionEnabled; - (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)b; - (void)setAutomaticDashSubstitutionEnabled:(BOOL)b; - (void)toggleAutomaticQuoteSubstitution:(id)s; - (NSUInteger)characterIndexForInsertionAtPoint:(NSPoint)p; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
#define STEP(n) do { fprintf(stderr, "step %d\n", n); } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		STEP(1); NSScrollView *sv = [NSTextView scrollableTextView]; NSTextView *tv = [sv documentView];
		CHECK([sv hasVerticalScroller]); CHECK([tv isKindOfClass: [NSTextView class]]); CHECK([tv isVerticallyResizable]); CHECK(![tv isHorizontallyResizable]); CHECK([[tv textContainer] widthTracksTextView]);
		NSTextView *plain = [[NSTextView scrollablePlainDocumentContentTextView] documentView]; CHECK(![plain isRichText]);
		CHECK([[NSTextView fieldEditor] isFieldEditor]);
		STEP(2); NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 200) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO]; [w setContentView: sv]; [w makeFirstResponder: tv];
		STEP(3); CHECK(![tv isAutomaticQuoteSubstitutionEnabled]);
		[tv insertText: @"\""]; CHECK([[tv string] isEqual: @"\""]);
		STEP(4); [tv setString: @""]; [tv toggleAutomaticQuoteSubstitution: nil]; CHECK([tv isAutomaticQuoteSubstitutionEnabled]); [tv setAutomaticDashSubstitutionEnabled: YES];
		[tv insertText: @"\""]; [tv insertText: @"a"]; [tv insertText: @"\""]; [tv insertText: @" "]; [tv insertText: @"d"]; [tv insertText: @"'"]; [tv insertText: @"s"]; [tv insertText: @" "]; [tv insertText: @"-"]; [tv insertText: @"-"];
		CHECK([[tv string] isEqual: @"“a” d’s —"]);
		STEP(5); [tv setString: @"hello world"]; [tv layoutManager];
		NSUInteger i0 = [tv characterIndexForInsertionAtPoint: NSMakePoint(2, 5)], i1 = [tv characterIndexForInsertionAtPoint: NSMakePoint(1000, 5)];
		CHECK(i0 == 0); CHECK(i1 == 11);
	}
	printf(fails ? "textview: %d failed\n" : "textview ok\n", fails);
	return fails != 0;
}

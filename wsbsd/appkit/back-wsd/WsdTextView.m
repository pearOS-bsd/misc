/* NSTextView of macOS 12+ that GNUstep lacks: the scrollable constructors (+scrollableTextView and the plain / document variants, +fieldEditor), automatic quote and dash substitution while typing
 * (and the other substitution switches, which the user's defaults set and the toggle actions flip), characterIndexForInsertionAtPoint:, showFindIndicatorForRange: (the yellow flash),
 * highlight: and -toggleAutomatic... actions. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <float.h>

@interface NSLayoutManager (WsdPointLookup) - (NSUInteger)characterIndexForPoint:(NSPoint)p inTextContainer:(NSTextContainer *)tc fractionOfDistanceBetweenInsertionPoints:(CGFloat *)fraction; @end
static char kQuote, kDash, kLink, kReplace, kSpelling, kData, kCompletion, kGrammar, kFindBar, kIncr, kOrient;
static BOOL Flag(id self, char *key, NSString *defaultsKey)
{
	NSNumber *n = objc_getAssociatedObject(self, key);
	if (n) return [n boolValue];
	return defaultsKey ? [[NSUserDefaults standardUserDefaults] boolForKey: defaultsKey] : NO;
}
static void SetFlag(id self, char *key, BOOL v) { objc_setAssociatedObject(self, key, [NSNumber numberWithBool: v], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@implementation NSTextView (WsdMacOS)
+ (NSScrollView *)wsdScrollableWithPlain:(BOOL)plain document:(BOOL)doc
{
	NSScrollView *sv = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)] autorelease];
	[sv setHasVerticalScroller: YES]; [sv setHasHorizontalScroller: NO]; [sv setBorderType: NSNoBorder]; [sv setAutohidesScrollers: YES];
	NSSize cs = [sv contentSize];
	NSTextView *tv = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, cs.width, cs.height)] autorelease];
	[tv setMinSize: NSMakeSize(0, cs.height)]; [tv setMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];
	[tv setVerticallyResizable: YES]; [tv setHorizontallyResizable: NO]; [tv setAutoresizingMask: NSViewWidthSizable];
	[[tv textContainer] setContainerSize: NSMakeSize(cs.width, FLT_MAX)]; [[tv textContainer] setWidthTracksTextView: YES];
	if (plain) { [tv setRichText: NO]; [tv setImportsGraphics: NO]; [tv setUsesFontPanel: NO]; [tv setAllowsUndo: YES]; }
	else if (doc) { [tv setRichText: YES]; [tv setImportsGraphics: YES]; [tv setUsesFontPanel: YES]; [tv setUsesRuler: YES]; [tv setAllowsUndo: YES]; }
	[sv setDocumentView: tv];
	return sv;
}
+ (NSScrollView *)scrollableTextView { return [self wsdScrollableWithPlain: NO document: NO]; }
+ (NSScrollView *)scrollablePlainDocumentContentTextView { return [self wsdScrollableWithPlain: YES document: NO]; }
+ (NSScrollView *)scrollableDocumentContentTextView { return [self wsdScrollableWithPlain: NO document: YES]; }
+ (NSTextView *)fieldEditor
{
	NSTextView *tv = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)] autorelease];
	[tv setFieldEditor: YES]; [tv setRichText: NO]; [tv setHorizontallyResizable: YES]; [tv setVerticallyResizable: NO];
	[tv setMinSize: NSMakeSize(0, 20)]; [tv setMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];
	[[tv textContainer] setContainerSize: NSMakeSize(FLT_MAX, FLT_MAX)]; [[tv textContainer] setWidthTracksTextView: NO];
	return tv;
}
+ (BOOL)stronglyReferencesTextStorage { return YES; }
+ (NSTextView *)textViewUsingTextLayoutManager:(BOOL)b { return [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)] autorelease]; }
- (id)initUsingTextLayoutManager:(BOOL)b { return [self initWithFrame: NSMakeRect(0, 0, 100, 100)]; }

- (BOOL)isAutomaticQuoteSubstitutionEnabled { return Flag(self, &kQuote, @"NSAutomaticQuoteSubstitutionEnabled"); }
- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)b { SetFlag(self, &kQuote, b); }
- (BOOL)isAutomaticDashSubstitutionEnabled { return Flag(self, &kDash, @"NSAutomaticDashSubstitutionEnabled"); }
- (void)setAutomaticDashSubstitutionEnabled:(BOOL)b { SetFlag(self, &kDash, b); }
- (BOOL)isAutomaticLinkDetectionEnabled { return Flag(self, &kLink, nil); }
- (void)setAutomaticLinkDetectionEnabled:(BOOL)b { SetFlag(self, &kLink, b); }
- (BOOL)isAutomaticTextReplacementEnabled { return Flag(self, &kReplace, @"NSAutomaticTextReplacementEnabled"); }
- (void)setAutomaticTextReplacementEnabled:(BOOL)b { SetFlag(self, &kReplace, b); }
- (BOOL)isAutomaticSpellingCorrectionEnabled { return Flag(self, &kSpelling, @"NSAutomaticSpellingCorrectionEnabled"); }
- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)b { SetFlag(self, &kSpelling, b); }
- (BOOL)isAutomaticDataDetectionEnabled { return Flag(self, &kData, nil); }
- (void)setAutomaticDataDetectionEnabled:(BOOL)b { SetFlag(self, &kData, b); }
- (BOOL)isAutomaticTextCompletionEnabled { return Flag(self, &kCompletion, nil); }
- (void)setAutomaticTextCompletionEnabled:(BOOL)b { SetFlag(self, &kCompletion, b); }
- (BOOL)isGrammarCheckingEnabled { return Flag(self, &kGrammar, @"NSGrammarCheckingEnabled"); }
- (void)setGrammarCheckingEnabled:(BOOL)b { SetFlag(self, &kGrammar, b); }
- (BOOL)usesFindBar { return Flag(self, &kFindBar, nil); }
- (void)setUsesFindBar:(BOOL)b { SetFlag(self, &kFindBar, b); }
- (BOOL)isIncrementalSearchingEnabled { return Flag(self, &kIncr, nil); }
- (void)setIncrementalSearchingEnabled:(BOOL)b { SetFlag(self, &kIncr, b); }
- (void)toggleAutomaticQuoteSubstitution:(id)s { [self setAutomaticQuoteSubstitutionEnabled: ![self isAutomaticQuoteSubstitutionEnabled]]; }
- (void)toggleAutomaticDashSubstitution:(id)s { [self setAutomaticDashSubstitutionEnabled: ![self isAutomaticDashSubstitutionEnabled]]; }
- (void)toggleAutomaticLinkDetection:(id)s { [self setAutomaticLinkDetectionEnabled: ![self isAutomaticLinkDetectionEnabled]]; }
- (void)toggleAutomaticTextReplacement:(id)s { [self setAutomaticTextReplacementEnabled: ![self isAutomaticTextReplacementEnabled]]; }
- (void)toggleAutomaticSpellingCorrection:(id)s { [self setAutomaticSpellingCorrectionEnabled: ![self isAutomaticSpellingCorrectionEnabled]]; }
- (void)toggleAutomaticDataDetection:(id)s { [self setAutomaticDataDetectionEnabled: ![self isAutomaticDataDetectionEnabled]]; }
- (void)toggleAutomaticTextCompletion:(id)s { [self setAutomaticTextCompletionEnabled: ![self isAutomaticTextCompletionEnabled]]; }
- (void)toggleGrammarChecking:(id)s { [self setGrammarCheckingEnabled: ![self isGrammarCheckingEnabled]]; }

- (NSUInteger)characterIndexForInsertionAtPoint:(NSPoint)p
{
	NSLayoutManager *lm = [self layoutManager]; NSTextContainer *tc = [self textContainer]; if (!lm || !tc) return NSNotFound;
	NSPoint o = [self textContainerOrigin]; NSPoint q = NSMakePoint(p.x - o.x, p.y - o.y);
	CGFloat frac = 0; NSUInteger i = [lm characterIndexForPoint: q inTextContainer: tc fractionOfDistanceBetweenInsertionPoints: &frac];
	if (i == NSNotFound) return i;
	if (frac >= 0.5 && i < [[self textStorage] length]) i++;
	return i;
}
- (void)showFindIndicatorForRange:(NSRange)r
{
	if (NSMaxRange(r) > [[self textStorage] length]) return;
	[self scrollRangeToVisible: r]; [self setSelectedRange: r];
	NSLayoutManager *lm = [self layoutManager];
	[lm addTemporaryAttribute: NSBackgroundColorAttributeName value: [NSColor colorWithCalibratedRed: 1 green: 0.93 blue: 0.2 alpha: 1] forCharacterRange: r];
	[self performSelector: @selector(wsdClearFind:) withObject: [NSValue valueWithRange: r] afterDelay: 0.7];
}
- (void)wsdClearFind:(NSValue *)v
{
	NSRange r = [v rangeValue]; if (NSMaxRange(r) > [[self textStorage] length]) return;
	[[self layoutManager] removeTemporaryAttribute: NSBackgroundColorAttributeName forCharacterRange: r];
}
- (void)highlight:(id)sender { NSRange r = [self selectedRange]; if (r.length) [self showFindIndicatorForRange: r]; }
@end

/* NSLayoutManager's point-to-character lookup (10.5): the character nearest to a point of the container, and how far the point is between its insertion points */
@implementation NSLayoutManager (WsdPointLookup)
- (NSUInteger)characterIndexForPoint:(NSPoint)p inTextContainer:(NSTextContainer *)tc fractionOfDistanceBetweenInsertionPoints:(CGFloat *)fraction
{
	if (fraction) *fraction = 0;
	if ([self numberOfGlyphs] == 0) return NSNotFound;
	CGFloat f = 0; NSUInteger g = [self glyphIndexForPoint: p inTextContainer: tc fractionOfDistanceThroughGlyph: &f];
	if (g >= [self numberOfGlyphs]) return NSNotFound;
	if (fraction) *fraction = f;
	return [self characterIndexForGlyphAtIndex: g];
}
@end

/* the substitutions while typing */
static IMP origInsert;
static void wsdInsert(NSTextView *self, SEL _cmd, id str)
{
	NSString *s = [str isKindOfClass: [NSAttributedString class]] ? [str string] : str;
	if ([s isKindOfClass: [NSString class]] && [s length] == 1 && ![self isFieldEditor])
	{
		unichar c = [s characterAtIndex: 0]; NSRange sel = [self selectedRange]; NSString *all = [[self textStorage] string];
		unichar prev = sel.location > 0 ? [all characterAtIndex: sel.location - 1] : 0;
		BOOL opening = sel.location == 0 || [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember: prev] || (prev && wcschr(L"([{—–-“‘", prev));
		if ([self isAutomaticQuoteSubstitutionEnabled] && (c == '"' || c == '\''))
		{
			NSString *r = c == '"' ? (opening ? @"“" : @"”") : (opening ? @"‘" : @"’");
			str = [str isKindOfClass: [NSAttributedString class]] ? [[[NSAttributedString alloc] initWithString: r attributes: [self typingAttributes]] autorelease] : r;
		}
		else if ([self isAutomaticDashSubstitutionEnabled] && c == '-' && prev == '-' && sel.length == 0)
		{
			NSRange pr = NSMakeRange(sel.location - 1, 1);
			if ([self shouldChangeTextInRange: pr replacementString: @"—"]) { [[self textStorage] replaceCharactersInRange: pr withString: @"—"]; [self didChangeText]; return; }
		}
	}
	((void (*)(id, SEL, id))origInsert)(self, _cmd, str);
}
@interface WsdTextViewInit : NSObject @end
@implementation WsdTextViewInit
+ (void)load { Method m = class_getInstanceMethod([NSTextView class], @selector(insertText:)); if (m) { origInsert = method_getImplementation(m); class_replaceMethod([NSTextView class], @selector(insertText:), (IMP)wsdInsert, method_getTypeEncoding(m)); } }
@end

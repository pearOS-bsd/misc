/* Cocoa bindings that GNUstep does not expose, found with the applications of the test list (Sloth: "No binding exposed on NSMenuItem for value", NSPopUpButtonCell selectedValue, NSTreeController sortDescriptors). GNUstep's binding engine (GSKeyValueBinding) observes the destination and sets the key
 * of the bound object with -setValue:forKey:, for the names the class exposes; what is added here is the exposure and the keys: a menu item's `value` is its check mark (the BOOL of the model, toggled by the click and written back), the pop-up button cell's `selectedValue` / `selectedTag` / `selectedIndex` select an item
 * (and a selection made by the user is written back), NSTreeController exposes `sortDescriptors`. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kToggleKey = &kToggleKey, *kSelKey = &kSelKey;

/* the reverse path: the engine's GSKeyValueBinding of a source object (private class, found by name) writes the source's value back to the model */
static void WSBReverse(id src, NSString *binding)
{
	Class kvb = NSClassFromString(@"GSKeyValueBinding"); if (!kvb) return;
	id b = ((id (*)(id, SEL, id, id))objc_msgSend)(kvb, NSSelectorFromString(@"getBinding:forObject:"), binding, src);
	if (b) ((void (*)(id, SEL, id))objc_msgSend)(b, NSSelectorFromString(@"reverseSetValueFor:"), binding);
}

/* a bound menu item toggles itself when it is chosen (the Mac does that: the item has the action of a check box) and then forwards the action it had */
@interface WSBMenuToggle : NSObject { @public __weak NSMenuItem *item; id origTarget; SEL origAction; } - (void)fire:(id)sender; @end
@implementation WSBMenuToggle
- (void)fire:(id)sender
{
	NSMenuItem *i = item; if (!i) return;
	[i setState: [i state] == NSOnState ? NSOffState : NSOnState]; WSBReverse(i, @"value");
	if (origAction) [NSApp sendAction: origAction to: origTarget from: i];
}
@end

@implementation NSMenuItem (WSBBindings)
- (id)value { return @([self state] == NSOnState); }
- (void)setValue:(id)v
{
	BOOL on = [v respondsToSelector: @selector(boolValue)] && [v boolValue]; [self setState: on ? NSOnState : NSOffState];
	if (!objc_getAssociatedObject(self, kToggleKey)) {
		WSBMenuToggle *t = [WSBMenuToggle new]; t->item = self; t->origTarget = [self target]; t->origAction = [self action];
		objc_setAssociatedObject(self, kToggleKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setTarget: t]; [self setAction: @selector(fire:)];
	}
}
@end

@implementation NSPopUpButtonCell (WSBBindings)
- (id)selectedValue { return [[self selectedItem] title]; }
- (void)setSelectedValue:(id)v { if (!v || v == [NSNull null]) return; if ([self indexOfItemWithTitle: [v description]] >= 0) { objc_setAssociatedObject(self, kSelKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self selectItemWithTitle: [v description]]; objc_setAssociatedObject(self, kSelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } }
- (id)selectedTag { return @([[self selectedItem] tag]); }
- (void)setSelectedTag:(id)v { if (!v || v == [NSNull null]) return; objc_setAssociatedObject(self, kSelKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); { NSInteger ix = [[self menu] indexOfItemWithTag: [v integerValue]]; if (ix >= 0) [self selectItemAtIndex: ix]; } objc_setAssociatedObject(self, kSelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (id)selectedIndex { return @([self indexOfSelectedItem]); }
- (void)setSelectedIndex:(id)v { if (!v || v == [NSNull null]) return; NSInteger i = [v integerValue]; if (i < 0 || i >= [self numberOfItems]) return; objc_setAssociatedObject(self, kSelKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self selectItemAtIndex: i]; objc_setAssociatedObject(self, kSelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

static IMP origSelectItem;
static void WSBSelectItem(id self, SEL _cmd, NSMenuItem *it)
{
	((void (*)(id, SEL, id))origSelectItem)(self, _cmd, it);
	if (objc_getAssociatedObject(self, kSelKey)) return;       /* set by the model: not written back */
	for (NSString *b in @[ @"selectedValue", @"selectedTag", @"selectedIndex" ]) WSBReverse(self, b);
}

@interface WSBBindingsInit : NSObject @end
@implementation WSBBindingsInit
+ (void)load
{
	[NSMenuItem exposeBinding: @"value"];
	[NSTreeController exposeBinding: @"sortDescriptors"];
	for (NSString *b in @[ @"selectedValue", @"selectedTag", @"selectedIndex" ]) [NSPopUpButtonCell exposeBinding: b];
	Method m = class_getInstanceMethod([NSPopUpButtonCell class], @selector(selectItem:)); if (m && !origSelectItem) origSelectItem = method_setImplementation(m, (IMP)WSBSelectItem);
}
@end

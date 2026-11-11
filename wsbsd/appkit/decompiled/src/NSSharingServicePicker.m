/*
 * NSSharingServicePicker.m — behavioral-1:1 core.
 * See NSSharingServicePicker.h (service enumeration + presentation are stage2).
 */

#import "NSSharingServicePicker.h"
#import "NSMenuItem.h"

@implementation NSSharingServicePicker {
    NSArray *_items;
    NSArray<NSString *> *_excludedSharingServiceNames;
}

- (instancetype)initWithItems:(NSArray *)items
{
    self = [super init];
    if (self) {
        _items = [items copy] ?: @[];   /* measured: empty is accepted */
    }
    return self;
}

- (NSArray<NSString *> *)excludedSharingServiceNames { return _excludedSharingServiceNames; }
- (void)setExcludedSharingServiceNames:(NSArray<NSString *> *)names { _excludedSharingServiceNames = [names copy]; }

- (NSMenuItem *)standardShareMenuItem
{
    /* measured: title "Share…", no submenu (services menu is built lazily). */
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Share…" action:NULL keyEquivalent:@""];
    /* TODO(stage2): attach the share image + a lazily-populated services submenu. */
    return item;
}

- (void)showRelativeToRect:(NSRect)rect ofView:(NSView *)view preferredEdge:(NSRectEdge)preferredEdge
{
    /* TODO(stage2): enumerate applicable NSSharingServices for _items (minus
     * excludedSharingServiceNames), build the rollover menu and present it as a
     * popover anchored to rect/view/preferredEdge. */
}

- (void)close { /* TODO(stage2): dismiss the presented menu/popover. */ }

/* internal accessor for tests / later wiring */
- (NSArray *)_items { return _items; }

@end

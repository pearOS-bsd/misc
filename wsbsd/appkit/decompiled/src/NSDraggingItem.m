/*
 * NSDraggingItem.m — 1:1 (core). See NSDraggingItem.h for the interface evidence.
 *
 * item is the pasteboard writer passed at init. imageComponents returns the
 * explicitly-set component array, or, failing that, the result of the
 * imageComponentsProvider block (evaluated on demand, as AppKit does).
 * setDraggingFrame:contents: sets the frame and installs a single icon
 * component whose contents is `contents` and whose frame is the item's bounds.
 * The actual drag-session compositing is stage2.
 */
#import "NSDraggingItem.h"
#import "NSDraggingImageComponent.h"

@implementation NSDraggingItem {
    id _item;
    id _localObject;
    CGRect _frame;
    NSArray<NSDraggingImageComponent *> *_components;
    NSArray<NSDraggingImageComponent *> * (^_componentsProvider)(void);
}

- (instancetype)initWithPasteboardWriter:(id)pasteboardWriter
{
    self = [super init];
    if (self) { _item = pasteboardWriter; _frame = CGRectZero; }
    return self;
}

- (id)item { return _item; }
- (id)localObject { return _localObject; }
- (void)setLocalObject:(id)v { _localObject = v; }
- (CGRect)draggingFrame { return _frame; }
- (void)setDraggingFrame:(CGRect)v { _frame = v; }

- (NSArray<NSDraggingImageComponent *> *)imageComponents
{
    if (_components) return _components;
    if (_componentsProvider) return _componentsProvider();
    return @[];
}
- (void)setImageComponents:(NSArray<NSDraggingImageComponent *> *)v { _components = [v copy]; }

- (NSArray<NSDraggingImageComponent *> * (^)(void))imageComponentsProvider { return _componentsProvider; }
- (void)setImageComponentsProvider:(NSArray<NSDraggingImageComponent *> * (^)(void))p
{ _componentsProvider = [p copy]; }

- (void)setDraggingFrame:(CGRect)frame contents:(id)contents
{
    _frame = frame;
    NSDraggingImageComponent *c =
        [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
    c.contents = contents;
    c.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _components = @[ c ];
}

@end

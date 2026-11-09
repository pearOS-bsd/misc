/*
 * NSDraggingImageComponent.m — 1:1 (core). See the header for the evidence.
 *
 * A value object: key, contents and frame. The standard keys are "icon" and
 * "label". Compositing the components into the actual drag image is stage2.
 */
#import "NSDraggingImageComponent.h"

NSDraggingImageComponentKey const NSDraggingImageComponentIconKey = @"icon";
NSDraggingImageComponentKey const NSDraggingImageComponentLabelKey = @"label";

@implementation NSDraggingImageComponent {
    NSString *_key;
    id _contents;
    CGRect _frame;
}

- (instancetype)initWithKey:(NSDraggingImageComponentKey)key
{
    self = [super init];
    if (self) { _key = [key copy]; _frame = CGRectZero; }
    return self;
}

+ (instancetype)draggingImageComponentWithKey:(NSDraggingImageComponentKey)key
{
    return [[self alloc] initWithKey:key];
}

- (NSString *)key { return _key; }
- (void)setKey:(NSString *)key { _key = [key copy]; }
- (id)contents { return _contents; }
- (void)setContents:(id)contents { _contents = contents; }
- (CGRect)frame { return _frame; }
- (void)setFrame:(CGRect)frame { _frame = frame; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ key=%@ frame={%g,%g,%g,%g}", [super description],
            _key, _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height];
}

@end

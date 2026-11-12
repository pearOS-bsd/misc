/*
 * NSAccessibilityElement.m — behavioral-1:1 core. See the header.
 */

#import "NSAccessibilityElement.h"

@implementation NSAccessibilityElement {
    CGRect _accessibilityFrameInParentSpace;
    BOOL _accessibilityElement;
    CGRect _accessibilityFrame;
    NSAccessibilityRole _accessibilityRole;
    NSString *_accessibilitySubrole;
    NSString *_accessibilityLabel;
    NSString *_accessibilityTitle;
    NSString *_accessibilityIdentifier;
    id _accessibilityValue;
    __weak id _accessibilityParent;
    NSMutableArray *_children;
    BOOL _accessibilityEnabled;
    BOOL _accessibilityFocused;
}

+ (instancetype)accessibilityElementWithRole:(NSAccessibilityRole)role
                                       frame:(CGRect)frame
                                       label:(NSString *)label
                                      parent:(id)parent
{
    NSAccessibilityElement *e = [[self alloc] init];
    e->_accessibilityRole = [role copy];
    e->_accessibilityFrame = frame;
    e->_accessibilityLabel = [label copy];
    e->_accessibilityParent = parent;   /* sets parent link; does NOT add to parent's children */
    return e;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _accessibilityElement = YES;    /* measured */
        _children = [NSMutableArray array];
    }
    return self;
}

- (void)accessibilityAddChildElement:(NSAccessibilityElement *)childElement
{
    if (!childElement) return;
    if (![_children containsObject:childElement]) [_children addObject:childElement];
    childElement.accessibilityParent = self;   /* re-parent to the receiver */
}

- (CGRect)accessibilityFrameInParentSpace { return _accessibilityFrameInParentSpace; }
- (void)setAccessibilityFrameInParentSpace:(CGRect)r { _accessibilityFrameInParentSpace = r; }
- (BOOL)isAccessibilityElement { return _accessibilityElement; }
- (void)setAccessibilityElement:(BOOL)v { _accessibilityElement = v; }
- (CGRect)accessibilityFrame { return _accessibilityFrame; }
- (void)setAccessibilityFrame:(CGRect)r { _accessibilityFrame = r; }
- (NSAccessibilityRole)accessibilityRole { return _accessibilityRole; }
- (void)setAccessibilityRole:(NSAccessibilityRole)r { _accessibilityRole = [r copy]; }
- (NSString *)accessibilitySubrole { return _accessibilitySubrole; }
- (void)setAccessibilitySubrole:(NSString *)s { _accessibilitySubrole = [s copy]; }
- (NSString *)accessibilityLabel { return _accessibilityLabel; }
- (void)setAccessibilityLabel:(NSString *)s { _accessibilityLabel = [s copy]; }
- (NSString *)accessibilityTitle { return _accessibilityTitle; }
- (void)setAccessibilityTitle:(NSString *)s { _accessibilityTitle = [s copy]; }
- (NSString *)accessibilityIdentifier { return _accessibilityIdentifier; }
- (void)setAccessibilityIdentifier:(NSString *)s { _accessibilityIdentifier = [s copy]; }
- (id)accessibilityValue { return _accessibilityValue; }
- (void)setAccessibilityValue:(id)v { _accessibilityValue = v; }
- (id)accessibilityParent { return _accessibilityParent; }
- (void)setAccessibilityParent:(id)p { _accessibilityParent = p; }
- (NSArray *)accessibilityChildren { return _children.count ? [_children copy] : nil; } /* nil when empty (measured) */
- (void)setAccessibilityChildren:(NSArray *)c { _children = [c mutableCopy] ?: [NSMutableArray array]; }
- (BOOL)isAccessibilityEnabled { return _accessibilityEnabled; }
- (void)setAccessibilityEnabled:(BOOL)v { _accessibilityEnabled = v; }
- (BOOL)isAccessibilityFocused { return _accessibilityFocused; }
- (void)setAccessibilityFocused:(BOOL)v { _accessibilityFocused = v; }

@end

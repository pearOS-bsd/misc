/*
 * NSAccessibilityElement.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSAccessibilityElement, a lightweight stored-attribute accessibility element
 * (used to expose non-view UI, e.g. cells drawn by hand, to assistive tech).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSAccessibilityElement_interface.txt. The class adopts the full
 * NSAccessibility protocol; this core models the stored attributes that an
 * element actually carries plus the two class-specific entry points:
 * +accessibilityElementWithRole:frame:label:parent: and
 * -accessibilityAddChildElement:.
 *
 * Measured: the factory stores role/frame/label, sets isAccessibilityElement=YES
 * and self.accessibilityParent=parent (without adding self to the parent's
 * children); -accessibilityAddChildElement: appends to accessibilityChildren and
 * sets the child's parent to the receiver. The remaining ~60 NSAccessibility
 * attributes are plain stored accessors (added on demand); the AX runtime bridge
 * is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *NSAccessibilityRole;

@interface NSAccessibilityElement : NSObject

+ (instancetype)accessibilityElementWithRole:(NSAccessibilityRole)role
                                       frame:(CGRect)frame
                                       label:(nullable NSString *)label
                                      parent:(nullable id)parent;

- (void)accessibilityAddChildElement:(NSAccessibilityElement *)childElement;

@property CGRect accessibilityFrameInParentSpace;

/* stored NSAccessibility attributes modelled by this core */
@property (getter=isAccessibilityElement) BOOL accessibilityElement;
@property CGRect accessibilityFrame;
@property (nullable, copy) NSAccessibilityRole accessibilityRole;
@property (nullable, copy) NSString *accessibilitySubrole;
@property (nullable, copy) NSString *accessibilityLabel;
@property (nullable, copy) NSString *accessibilityTitle;
@property (nullable, copy) NSString *accessibilityIdentifier;
@property (nullable, strong) id accessibilityValue;
@property (nullable, weak) id accessibilityParent;
@property (nullable, copy) NSArray *accessibilityChildren;
@property (getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property (getter=isAccessibilityFocused) BOOL accessibilityFocused;

@end

NS_ASSUME_NONNULL_END

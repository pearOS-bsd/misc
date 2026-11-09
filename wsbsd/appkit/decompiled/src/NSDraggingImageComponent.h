/*
 * NSDraggingImageComponent.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSDraggingImageComponent : NSObject {
 *       @"NSString" _key;  @ _contents;  {CGRect} _frame;
 *   }
 *   @property (T@"NSString",C) key;  (T@,&) contents;  (T{CGRect}) frame;
 *   +draggingImageComponentWithKey: -initWithKey:
 *
 * One layer of a drag image: a key (icon/label), its contents (an NSImage or
 * CALayer) and its frame within the dragging item. A plain value object; the
 * compositing of components into the drag image is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSDraggingImageComponentKey NS_EXTENSIBLE_STRING_ENUM;
extern NSDraggingImageComponentKey const NSDraggingImageComponentIconKey;
extern NSDraggingImageComponentKey const NSDraggingImageComponentLabelKey;

@interface NSDraggingImageComponent : NSObject

+ (instancetype)draggingImageComponentWithKey:(NSDraggingImageComponentKey)key;
- (instancetype)initWithKey:(NSDraggingImageComponentKey)key;

@property (copy) NSDraggingImageComponentKey key;
@property (nullable, strong) id contents;   /* NSImage or CALayer */
@property CGRect frame;

@end

NS_ASSUME_NONNULL_END

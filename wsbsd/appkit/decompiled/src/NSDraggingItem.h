/*
 * NSDraggingItem.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSDraggingItem : NSObject {
 *       @ _item;  @ _localObject;  {CGRect} _frame;  @"NSArray" _components;
 *       @? _componentsProvider;
 *   }
 *   @property (T@,R) item;  (T@,&) localObject;  (T{CGRect}) draggingFrame;
 *   @property (T@"NSArray",C) imageComponents;  (T@?,C) imageComponentsProvider;
 *   -initWithPasteboardWriter: -setDraggingFrame:contents:
 *
 * One item being dragged: the pasteboard writer, an optional local object, the
 * dragging frame, and the drag-image components (set directly or produced by a
 * provider block). Compositing into the drag session is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSDraggingImageComponent;

@interface NSDraggingItem : NSObject

- (instancetype)initWithPasteboardWriter:(id)pasteboardWriter;

@property (readonly, strong) id item;
@property (nullable, strong) id localObject;
@property CGRect draggingFrame;
@property (copy) NSArray<NSDraggingImageComponent *> *imageComponents;
@property (nullable, copy) NSArray<NSDraggingImageComponent *> * (^imageComponentsProvider)(void);

- (void)setDraggingFrame:(CGRect)frame contents:(nullable id)contents;

@end

NS_ASSUME_NONNULL_END

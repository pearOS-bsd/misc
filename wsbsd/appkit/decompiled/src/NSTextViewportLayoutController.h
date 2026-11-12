/*
 * NSTextViewportLayoutController.h — 1:1 reimplementation (behavioral core) of
 * AppKit/TextKit 2's NSTextViewportLayoutController, which drives layout of just
 * the visible viewport for an NSTextLayoutManager.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSTextViewportLayoutController_interface.txt.
 *
 * This core reproduces construction (initWithTextLayoutManager: keeps the
 * manager, readonly weak) and the measured pre-layout state: delegate=nil,
 * viewportBounds=zero, viewportRange=nil. The viewport layout cycle
 * (layoutViewport and the relocate/adjust methods) needs the layout engine, so
 * it is TODO(stage2) and is a no-op here.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextLayoutManager, NSTextViewportLayoutController;

@protocol NSTextViewportLayoutControllerDelegate <NSObject>
@optional
- (CGRect)viewportBoundsForTextViewportLayoutController:(NSTextViewportLayoutController *)controller;
@end

@interface NSTextViewportLayoutController : NSObject

- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)textLayoutManager;

@property (nullable, weak) id<NSTextViewportLayoutControllerDelegate> delegate;
@property (readonly, weak, nullable) NSTextLayoutManager *textLayoutManager;
@property (readonly) CGRect viewportBounds;
@property (readonly, nullable) NSTextRange *viewportRange;

- (void)layoutViewport;
- (void)adjustViewportByVerticalOffset:(double)verticalOffset;
- (void)relocateViewportToTextLocation:(id<NSTextLocation>)textLocation;

@end

NS_ASSUME_NONNULL_END

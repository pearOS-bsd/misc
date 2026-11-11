/*
 * NSScrubberSelectionStyle.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSScrubberSelectionStyle, the factory that vends an NSScrubber's selection /
 * overlay view.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberSelectionStyle_interface.txt.
 *
 * This core reproduces the factory identity: the built-in style singletons and
 * the selectionStyleWithViewClass: custom path, whose -makeSelectionView
 * instantiates the supplied class 1:1. The built-in styles' private selection
 * views (outline / rounded-background renderers) are TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSColor, NSView;

@interface NSScrubberSelectionStyle : NSObject <NSCoding>

@property (class, readonly, strong) NSScrubberSelectionStyle *outlineOverlayStyle;
@property (class, readonly, strong) NSScrubberSelectionStyle *roundedBackgroundStyle;
+ (NSScrubberSelectionStyle *)nonHighlightingOutlineOverlayStyle;
+ (NSScrubberSelectionStyle *)roundedBackgroundStyleWithTintColor:(NSColor *)tintColor;
+ (instancetype)selectionStyleWithViewClass:(Class)viewClass;

- (nullable NSView *)makeSelectionView;

@end

NS_ASSUME_NONNULL_END

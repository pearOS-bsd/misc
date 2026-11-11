/*
 * NSViewAnimation.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSViewAnimation (a concrete NSAnimation subclass that animates view/window
 * frames and fade effects over the inherited progress timeline).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSViewAnimation_interface.txt. Real ivars: _viewAnimations
 * (NSArray of the per-target dictionaries), _viewAnimationInfo /
 * _windowAnimationInfo (NSMapTables of resolved per-frame animation state built
 * at _startAnimation / _setupAnimationInfo time).
 *
 * This core stores the viewAnimations descriptor array and, on
 * -setCurrentProgress:, interpolates each descriptor's start→end frame and
 * applies it to the target (anything responding to -setFrame:). The fade
 * effect's alpha application, the NSMapTable precomputation, window ordering,
 * and NSCoding are TODO(stage2).
 */

#import "NSAnimation.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSViewAnimationKey NS_TYPED_ENUM;
FOUNDATION_EXPORT NSViewAnimationKey const NSViewAnimationTargetKey;      /* NSView* / NSWindow* */
FOUNDATION_EXPORT NSViewAnimationKey const NSViewAnimationStartFrameKey;  /* NSValue(NSRect) */
FOUNDATION_EXPORT NSViewAnimationKey const NSViewAnimationEndFrameKey;    /* NSValue(NSRect) */
FOUNDATION_EXPORT NSViewAnimationKey const NSViewAnimationEffectKey;      /* NSViewAnimationEffectName */

typedef NSString * NSViewAnimationEffectName NS_TYPED_ENUM;
FOUNDATION_EXPORT NSViewAnimationEffectName const NSViewAnimationFadeInEffect;
FOUNDATION_EXPORT NSViewAnimationEffectName const NSViewAnimationFadeOutEffect;

@interface NSViewAnimation : NSAnimation {
    NSArray<NSDictionary<NSViewAnimationKey, id> *> *_viewAnimations;
}

- (instancetype)initWithViewAnimations:(NSArray<NSDictionary<NSViewAnimationKey, id> *> *)viewAnimations;
@property (copy) NSArray<NSDictionary<NSViewAnimationKey, id> *> *viewAnimations;

@end

NS_ASSUME_NONNULL_END

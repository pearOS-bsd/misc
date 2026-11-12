/*
 * NSATSTypesetter.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSATSTypesetter, the concrete NSTypesetter the text system uses by default.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSATSTypesetter_interface.txt.
 *
 * This core adds the +sharedTypesetter singleton on top of the NSTypesetter
 * configuration core (which it inherits unchanged — measured). The concrete
 * glyph-layout overrides are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTypesetter.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSATSTypesetter : NSTypesetter

@property (class, readonly, strong) NSATSTypesetter *sharedTypesetter;

@end

NS_ASSUME_NONNULL_END

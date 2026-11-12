/*
 * NSMovie.h — 1:1 reimplementation (behavioral core) of AppKit's NSMovie, the
 * legacy movie wrapper (QTKit-era, long deprecated).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSMovie_interface.txt. Real ivars: _data, _URL.
 *
 * The modern class is a degenerate archive-only wrapper: -data / -URL are nil
 * unless decoded from an archive (there is no public initWithData:/WithURL:),
 * and -QTMovie returns nil (QuickTime removed). This core reproduces that: a
 * plain -init is empty, NSCoding round-trips _data/_URL, -QTMovie is nil.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMovie : NSObject <NSCoding>

- (nullable instancetype)initWithMovie:(NSMovie *)movie;

@property (readonly, nullable) NSData *data;
@property (readonly, nullable) NSURL *URL;
@property (readonly, nullable) id QTMovie;

@end

NS_ASSUME_NONNULL_END

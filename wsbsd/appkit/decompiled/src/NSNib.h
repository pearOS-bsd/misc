/*
 * NSNib.h — 1:1 reimplementation (behavioral core) of AppKit's NSNib.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSNib_interface.txt. Real ivars: _data, _images, _sounds,
 * _bundle, _path, _reusableDecoder, and a packed _flags (_isKeyed /
 * _inheritsDecodeTimeBundle / _inheritsDecodeTimePath).
 *
 * Measured on this Mac: initWithNibData:bundle: keeps the archive data;
 * initWithNibNamed:bundle: resolves the named nib in the bundle (nil bundle →
 * main bundle) and RAISES NSInternalInconsistencyException when it is not found.
 *
 * This core reproduces the locate/load + nib-not-found raise and the identity
 * of a nib (name/data/bundle/path). The keyed-archive instantiation — decoding
 * the Interface Builder object graph, wiring outlets/actions, and returning the
 * top-level objects — is TODO(stage2); instantiate* currently returns NO with an
 * empty top-level-objects array.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSBundle;

@interface NSNib : NSObject <NSCoding>

- (nullable instancetype)initWithNibNamed:(NSString *)nibName bundle:(nullable NSBundle *)bundle;
- (nullable instancetype)initWithNibData:(NSData *)nibData bundle:(nullable NSBundle *)bundle;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)nibFileURL;

- (BOOL)instantiateWithOwner:(nullable id)owner topLevelObjects:(NSArray * _Nullable * _Nullable)topLevelObjects;

/* _flags bit, carried through archiving */
- (BOOL)inheritsDecodeTimeBundlePath;
- (void)setInheritsDecodeTimeBundlePath:(BOOL)flag;

@end

NS_ASSUME_NONNULL_END

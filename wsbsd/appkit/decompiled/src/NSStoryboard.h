/*
 * NSStoryboard.h — 1:1 reimplementation (behavioral core) of AppKit's NSStoryboard.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSStoryboard_interface.txt. Real ivars: _bundle, _storyboardFileName,
 * _identifierToNibNameMap, _identifierToExternalStoryboardReferenceMap,
 * _identifierToUUIDMap, _designatedEntryPointIdentifier, _mainMenu, …
 *
 * Measured on this Mac: +storyboardWithName:bundle: raises NSInvalidArgumentException
 * when the storyboard is not found in the bundle (1:1 message).
 *
 * This core reproduces the identity + identifier→nib/UUID lookup model via the
 * designated map-based initializer and the not-found raise. Loading the compiled
 * .storyboardc Info.plist and instantiating controllers from the keyed archive
 * are TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSBundle;
typedef NSString * NSStoryboardName;
typedef NSString * NSStoryboardSceneIdentifier;

@interface NSStoryboard : NSObject

@property (class, readonly, strong, nullable) NSStoryboard *mainStoryboard;
+ (instancetype)storyboardWithName:(NSStoryboardName)name bundle:(nullable NSBundle *)storyboardBundleOrNil;

/* designated map-based initializer (as the real class exposes it) */
- (instancetype)initWithBundle:(nullable NSBundle *)bundle
            storyboardFileName:(NSString *)fileName
         identifierToNibNameMap:(NSDictionary<NSString *, NSString *> *)nibMap
identifierToExternalStoryboardReferenceMap:(nullable NSDictionary *)refMap
            identifierToUUIDMap:(nullable NSDictionary<NSString *, NSString *> *)uuidMap
   designatedEntryPointIdentifier:(nullable NSString *)entryPoint
                       mainMenu:(nullable NSString *)mainMenu;

@property (readonly, copy) NSString *name;
@property (readonly, strong, nullable) NSBundle *containingBundle;

- (nullable NSString *)nibForControllerWithIdentifier:(NSString *)identifier;
- (BOOL)containsNibNamed:(NSString *)nibName;
- (nullable NSString *)uniqueIDForControllerIdentifier:(NSString *)identifier;

- (nullable id)instantiateInitialController;
- (id)instantiateControllerWithIdentifier:(NSStoryboardSceneIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END

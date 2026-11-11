/*
 * NSDictionaryController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSDictionaryController (: NSArrayController) and its key-value-pair element
 * class NSDictionaryControllerKeyValuePair.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSDictionaryController_interface.txt. Real ivars: _contentDictionary,
 * _initialKey/_initialValue, _includedKeys/_excludedKeys, localized-key maps, and
 * a packed _dictionaryControllerFlags.
 *
 * Measured on this Mac: initialKey default "key"; included/excludedKeys empty;
 * setting a dictionary content produces one key-value-pair per key in
 * arrangedObjects (localizedKey==key, explicitlyIncluded=NO); -newObject returns
 * an empty pair (key=nil, value=nil); -content reads the dictionary back.
 *
 * This core reproduces the dictionary⇄key-value-pair arrangement over the
 * NSArrayController backing, included/excluded-key handling and localized-key
 * mapping. CoreData, binding notifications, deep value copying and NSCoding are
 * TODO(stage2).
 */

#import "NSArrayController.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionaryControllerKeyValuePair : NSObject
@property (nullable, copy) NSString *key;
@property (nullable, strong) id value;
@property (nullable, copy) NSString *localizedKey;
@property (readonly, getter=isExplicitlyIncluded) BOOL explicitlyIncluded;
@end

@interface NSDictionaryController : NSArrayController

@property (nullable, copy) NSString *initialKey;      /* default "key" */
@property (nullable, strong) id initialValue;
@property (nullable, copy) NSArray<NSString *> *includedKeys;
@property (nullable, copy) NSArray<NSString *> *excludedKeys;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *localizedKeyDictionary;
@property (nullable, copy) NSString *localizedKeyTable;

- (NSDictionaryControllerKeyValuePair *)newObject;

@end

NS_ASSUME_NONNULL_END

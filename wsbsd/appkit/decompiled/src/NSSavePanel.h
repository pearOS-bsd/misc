/*
 * NSSavePanel.h — 1:1 reimplementation (core). NSPanel subclass.
 * Evidence ../evidence/save: properties are kept in a string-keyed internal
 * store ("nameFieldStringValue", "canCreateDirectories", "directoryURL", ...).
 * We model them as direct ivars with the same contract (keyed store is stage2).
 * runModal / the file browser UI are stage2.
 */
#import "NSPanel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSavePanel : NSPanel
@property (copy) NSString *nameFieldStringValue;
@property (nullable, copy) NSURL *directoryURL;
@property BOOL canCreateDirectories;
@property BOOL showsHiddenFiles;
@property BOOL allowsOtherFileTypes;
@end

NS_ASSUME_NONNULL_END

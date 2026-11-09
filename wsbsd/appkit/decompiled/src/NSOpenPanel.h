/*
 * NSOpenPanel.h — 1:1 reimplementation (core). NSSavePanel subclass.
 * Evidence ../evidence/open: canChooseFiles/canChooseDirectories/
 * allowsMultipleSelection/resolvesAliases go through the inherited keyed store;
 * modelled as direct ivars (stage2: keyed store + file browser + runModal).
 */
#import "NSSavePanel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSOpenPanel : NSSavePanel
@property BOOL canChooseFiles;
@property BOOL canChooseDirectories;
@property BOOL allowsMultipleSelection;
@property BOOL resolvesAliases;
@end

NS_ASSUME_NONNULL_END

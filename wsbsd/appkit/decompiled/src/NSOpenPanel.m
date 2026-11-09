/*
 * NSOpenPanel.m — 1:1 (core). Evidence ../evidence/open: canChooseFiles
 * 0x185af74fc etc. read/write the inherited keyed store (keys canChooseFiles,
 * canChooseDirectories, allowsMultipleSelection). Modelled as direct ivars.
 */
#import "NSOpenPanel.h"

@implementation NSOpenPanel {
    BOOL _canChooseFiles;
    BOOL _canChooseDirectories;
    BOOL _allowsMultipleSelection;
    BOOL _resolvesAliases;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _canChooseFiles = YES;        /* open panels choose files by default */
        _canChooseDirectories = NO;
        _allowsMultipleSelection = NO;
        _resolvesAliases = YES;
    }
    return self;
}

- (BOOL)canChooseFiles { return _canChooseFiles; }
- (void)setCanChooseFiles:(BOOL)v { _canChooseFiles = v; }
- (BOOL)canChooseDirectories { return _canChooseDirectories; }
- (void)setCanChooseDirectories:(BOOL)v { _canChooseDirectories = v; }
- (BOOL)allowsMultipleSelection { return _allowsMultipleSelection; }
- (void)setAllowsMultipleSelection:(BOOL)v { _allowsMultipleSelection = v; }
- (BOOL)resolvesAliases { return _resolvesAliases; }
- (void)setResolvesAliases:(BOOL)v { _resolvesAliases = v; }

@end

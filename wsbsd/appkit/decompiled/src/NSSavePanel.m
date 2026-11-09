/*
 * NSSavePanel.m — 1:1 (core). Evidence ../evidence/save: accessors read/write a
 * string-keyed store (nameFieldStringValue 0x185b25054, canCreateDirectories
 * 0x185b24bd8 via bool-for-key, directoryURL 0x185b23188 via object-for-key).
 * Modelled as direct ivars here; TODO(stage2): the keyed store + file browser.
 */
#import "NSSavePanel.h"

@implementation NSSavePanel {
    NSString *_nameFieldStringValue;
    NSURL *_directoryURL;
    BOOL _canCreateDirectories;
    BOOL _showsHiddenFiles;
    BOOL _allowsOtherFileTypes;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _nameFieldStringValue = @"";
        _canCreateDirectories = YES;   /* save panels allow new folders by default */
    }
    return self;
}

- (NSString *)nameFieldStringValue { return _nameFieldStringValue ?: @""; }
- (void)setNameFieldStringValue:(NSString *)v { _nameFieldStringValue = [v copy] ?: @""; }

- (NSURL *)directoryURL { return _directoryURL; }
- (void)setDirectoryURL:(NSURL *)v { _directoryURL = [v copy]; }

- (BOOL)canCreateDirectories { return _canCreateDirectories; }
- (void)setCanCreateDirectories:(BOOL)v { _canCreateDirectories = v; }

- (BOOL)showsHiddenFiles { return _showsHiddenFiles; }
- (void)setShowsHiddenFiles:(BOOL)v { _showsHiddenFiles = v; }

- (BOOL)allowsOtherFileTypes { return _allowsOtherFileTypes; }
- (void)setAllowsOtherFileTypes:(BOOL)v { _allowsOtherFileTypes = v; }

@end

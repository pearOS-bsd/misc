/*
 * NSDocument.m — 1:1 (core). See NSDocument.h for the interface evidence.
 *
 * Edit state is a change count driven by updateChangeCount:: NSChangeDone/Redone
 * increment, NSChangeUndone decrements, NSChangeCleared resets to 0;
 * isDocumentEdited is changeCount != 0 (the discardable bit is tracked
 * separately and does not by itself mark the document edited). displayName
 * prefers an explicit name, else the file URL's last component without its
 * extension, else "Untitled". addWindowController: links the controller back to
 * this document. File I/O, autosave and the undo manager are stage2.
 */
#import "NSDocument.h"
#import "NSWindowController.h"

@implementation NSDocument {
    NSURL *_fileURL;
    NSString *_fileType;
    NSString *_displayName;
    NSInteger _changeCount;
    BOOL _hasDiscardableChanges;
    NSMutableArray<NSWindowController *> *_windowControllers;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _windowControllers = [NSMutableArray array]; }
    return self;
}

- (NSURL *)fileURL { return _fileURL; }
- (void)setFileURL:(NSURL *)v { _fileURL = [v copy]; }
- (NSString *)fileType { return _fileType; }
- (void)setFileType:(NSString *)v { _fileType = [v copy]; }

- (void)setDisplayName:(NSString *)name { _displayName = [name copy]; }
- (NSString *)displayName
{
    if (_displayName) return _displayName;
    if (_fileURL) {
        NSString *last = _fileURL.lastPathComponent;
        NSString *base = last.stringByDeletingPathExtension;
        if (base.length) return base;
    }
    return @"Untitled";
}

- (BOOL)isDocumentEdited { return _changeCount != 0; }

- (void)updateChangeCount:(NSDocumentChangeType)change
{
    switch (change & 0xff) {
        case NSChangeDone:
        case NSChangeRedone:          _changeCount += 1; break;
        case NSChangeUndone:          _changeCount -= 1; break;
        case NSChangeCleared:
        case NSChangeAutosaved:       _changeCount = 0; _hasDiscardableChanges = NO; break;
        case NSChangeReadOtherContents: break;
        default: break;
    }
    if (change & NSChangeDiscardable) _hasDiscardableChanges = YES;
}

- (NSArray<NSWindowController *> *)windowControllers { return [_windowControllers copy]; }

- (void)addWindowController:(NSWindowController *)wc
{
    if (!wc || [_windowControllers containsObject:wc]) return;
    [_windowControllers addObject:wc];
    if (wc.document != self) wc.document = self;
}

- (void)removeWindowController:(NSWindowController *)wc
{
    if (![_windowControllers containsObject:wc]) return;
    [_windowControllers removeObject:wc];
    if (wc.document == self) wc.document = nil;
}

@end

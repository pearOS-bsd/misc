/*
 * NSDocument.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSDocument : NSObject <NSEditorRegistration, NSFilePresenter, …> {
 *       @"NSWindow" _window;  @ _windowControllers;  @"NSURL" _fileURL;
 *       @"NSString" _fileType;  @ _displayName;  @"NSUndoManager" _undoManager;
 *       {__docFlags="inClose"b1 …} _docFlags;  q _documentUniquingNumber; …
 *   }
 *   -fileURL -setFileURL: -fileType -setFileType: -displayName
 *   -isDocumentEdited -updateChangeCount: -windowControllers
 *   -addWindowController: -removeWindowController:
 *
 * The core tracks fileURL/fileType/displayName, the edit state via a change
 * count driven by updateChangeCount:, and the window-controller list. Reading/
 * writing files, autosave, undo manager and the save panel are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSDocumentChangeType) {
    NSChangeDone = 0,
    NSChangeUndone = 1,
    NSChangeCleared = 2,
    NSChangeReadOtherContents = 3,
    NSChangeAutosaved = 4,
    NSChangeRedone = 5,
    NSChangeDiscardable = 256,
};

@class NSWindowController;

@interface NSDocument : NSObject

@property (nullable, copy) NSURL *fileURL;
@property (nullable, copy) NSString *fileType;
@property (readonly, copy) NSString *displayName;
- (void)setDisplayName:(nullable NSString *)displayNameOrNil;

@property (readonly, getter=isDocumentEdited) BOOL documentEdited;
- (void)updateChangeCount:(NSDocumentChangeType)change;

@property (readonly, copy) NSArray<NSWindowController *> *windowControllers;
- (void)addWindowController:(NSWindowController *)windowController;
- (void)removeWindowController:(NSWindowController *)windowController;

@end

NS_ASSUME_NONNULL_END

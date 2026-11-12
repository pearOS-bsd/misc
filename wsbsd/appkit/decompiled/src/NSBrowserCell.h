/*
 * NSBrowserCell.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSBrowserCell, the cell an NSBrowser draws for each row.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSBrowserCell_interface.txt.
 *
 * NSBrowserCell is an NSCell (measured). This core reproduces the state:
 * initTextCell: sets the title with isLeaf=NO and isLoaded=YES (measured),
 * leaf/loaded/image/alternateImage, stringValue, and -reset/-set for the
 * highlight+state pair. The system branch (disclosure) images and real drawing
 * are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSCell.h"

NS_ASSUME_NONNULL_BEGIN

@class NSImage;

@interface NSBrowserCell : NSCell

- (instancetype)initTextCell:(NSString *)string;
- (instancetype)initImageCell:(nullable NSImage *)image;

@property (class, readonly, nullable, strong) NSImage *branchImage;
@property (class, readonly, nullable, strong) NSImage *highlightedBranchImage;

@property (getter=isLeaf) BOOL leaf;
@property (getter=isLoaded) BOOL loaded;
@property (nullable, copy) NSString *stringValue;
@property (nullable, strong) NSImage *image;
@property (nullable, strong) NSImage *alternateImage;

- (void)reset;
- (void)set;

@end

NS_ASSUME_NONNULL_END

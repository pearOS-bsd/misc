/*
 * NSTextSelectionNavigation.h — 1:1 reimplementation (behavioral core) of
 * AppKit/TextKit 2's NSTextSelectionNavigation, which resolves caret movement,
 * hit-testing and deletion over a text selection data source.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSTextSelectionNavigation_interface.txt.
 *
 * This core reproduces construction (initWithDataSource: keeps a weak data
 * source) and the configuration flags: allowsNonContiguousRanges (YES — measured),
 * rotatesCoordinateSystemForLayoutOrientation (NO). The geometric resolution
 * methods need the layout engine, so they are TODO(stage2) and return nil/empty.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSTextSelection;
@protocol NSTextSelectionDataSource;

typedef NS_ENUM(NSInteger, NSTextSelectionNavigationDirection) {
    NSTextSelectionNavigationDirectionForward = 0,
    NSTextSelectionNavigationDirectionBackward = 1,
    NSTextSelectionNavigationDirectionRight = 2,
    NSTextSelectionNavigationDirectionLeft = 3,
    NSTextSelectionNavigationDirectionUp = 4,
    NSTextSelectionNavigationDirectionDown = 5,
};

typedef NS_ENUM(NSInteger, NSTextSelectionNavigationDestination) {
    NSTextSelectionNavigationDestinationCharacter = 0,
    NSTextSelectionNavigationDestinationWord = 1,
    NSTextSelectionNavigationDestinationLine = 2,
    NSTextSelectionNavigationDestinationSentence = 3,
    NSTextSelectionNavigationDestinationParagraph = 4,
    NSTextSelectionNavigationDestinationContainer = 5,
    NSTextSelectionNavigationDestinationDocument = 6,
};

@interface NSTextSelectionNavigation : NSObject

- (instancetype)initWithDataSource:(nullable id<NSTextSelectionDataSource>)dataSource;

@property (nullable, weak) id<NSTextSelectionDataSource> textSelectionDataSource;
@property BOOL allowsNonContiguousRanges;
@property BOOL rotatesCoordinateSystemForLayoutOrientation;

- (nullable NSTextSelection *)destinationSelectionForTextSelection:(NSTextSelection *)textSelection
                                                         direction:(NSTextSelectionNavigationDirection)direction
                                                       destination:(NSTextSelectionNavigationDestination)destination
                                                         extending:(BOOL)extending
                                                          confined:(BOOL)confined;

@end

NS_ASSUME_NONNULL_END

/*
 * NSAlert.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/alert: messageText @0x40, alertStyle @0xd0, buttons @0x28,
 * showsHelp @0xe1. addButtonWithTitle: builds an NSButton and appends it.
 * The shipping messageText is stored as an NSAttributedString; we keep the plain
 * string (stage2). The panel layout / runModal are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSButton.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSAlertStyle) {
    NSAlertStyleWarning = 0,
    NSAlertStyleInformational = 1,
    NSAlertStyleCritical = 2,
};

@interface NSAlert : NSObject
@property (copy) NSString *messageText;
@property (copy) NSString *informativeText;
@property NSAlertStyle alertStyle;
@property BOOL showsHelp;
@property (readonly, copy) NSArray<NSButton *> *buttons;
- (NSButton *)addButtonWithTitle:(NSString *)title;
@end

NS_ASSUME_NONNULL_END

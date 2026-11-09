/*
 * NSSharingService.m — 1:1 (core). See NSSharingService.h for the evidence.
 *
 * A custom service stores its title/images/handler and the editable
 * recipients/subject/menuItemTitle. canPerformWithItems: is YES when there is at
 * least one item (a custom service imposes no type restriction); performWithItems:
 * runs the handler block. Built-in system services and the real share-sheet UI
 * are stage2.
 */
#import "NSSharingService.h"

@implementation NSSharingService {
    NSString *_title;
    id _image;
    id _alternateImage;
    void (^_handler)(void);
    NSString *_menuItemTitle;
    NSArray *_recipients;
    NSString *_subject;
    __weak id _delegate;
}

- (instancetype)initWithTitle:(NSString *)title
                        image:(id)image
               alternateImage:(id)alternateImage
                      handler:(void (^)(void))block
{
    self = [super init];
    if (self) {
        _title = [title copy];
        _image = image;
        _alternateImage = alternateImage;
        _handler = [block copy];
    }
    return self;
}

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)d { _delegate = d; }
- (NSString *)title { return _title; }
- (id)image { return _image; }
- (id)alternateImage { return _alternateImage; }
- (NSString *)menuItemTitle { return _menuItemTitle ?: _title; }
- (void)setMenuItemTitle:(NSString *)v { _menuItemTitle = [v copy]; }
- (NSArray *)recipients { return _recipients; }
- (void)setRecipients:(NSArray *)v { _recipients = [v copy]; }
- (NSString *)subject { return _subject; }
- (void)setSubject:(NSString *)v { _subject = [v copy]; }

- (BOOL)canPerformWithItems:(NSArray *)items { return items.count > 0; }

- (void)performWithItems:(NSArray *)items
{
    if (![self canPerformWithItems:items]) return;
    if (_handler) _handler();   /* custom service: run the handler (stage2: share sheet) */
}

@end

/*
 * NSStoryboardSegue.m — 1:1 (core). See NSStoryboardSegue.h for the evidence.
 *
 * Stores identifier/source/destination and the perform/prepare handler blocks.
 * +segue…performHandler: builds a segue whose -perform runs that block. A plain
 * NSStoryboardSegue with no handler does nothing on -perform (AppKit's concrete
 * presentation segues override -perform; that presentation is stage2).
 */
#import "NSStoryboardSegue.h"

@implementation NSStoryboardSegue {
    NSString *_identifier;
    id _sourceController;
    id _destinationController;
    void (^_prepareHandler)(void);
    void (^_performHandler)(void);
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                            source:(id)sourceController
                       destination:(id)destinationController
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _sourceController = sourceController;
        _destinationController = destinationController;
    }
    return self;
}

+ (instancetype)segueWithIdentifier:(NSString *)identifier
                             source:(id)sourceController
                        destination:(id)destinationController
                     performHandler:(void (^)(void))performHandler
{
    NSStoryboardSegue *s = [[self alloc] initWithIdentifier:identifier
                                                     source:sourceController
                                                destination:destinationController];
    s.performHandler = performHandler;
    return s;
}

- (NSString *)identifier { return _identifier; }
- (id)sourceController { return _sourceController; }
- (id)destinationController { return _destinationController; }
- (void (^)(void))prepareHandler { return _prepareHandler; }
- (void)setPrepareHandler:(void (^)(void))h { _prepareHandler = [h copy]; }
- (void (^)(void))performHandler { return _performHandler; }
- (void)setPerformHandler:(void (^)(void))h { _performHandler = [h copy]; }

- (void)perform
{
    if (_performHandler) _performHandler();
    /* else: concrete AppKit segues drive the presentation here (stage2). */
}

@end

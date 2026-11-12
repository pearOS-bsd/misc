/*
 * NSTextContentManager.m — behavioral-1:1 core. See the header.
 */

#import "NSTextContentManager.h"

@implementation NSTextContentManager {
    __weak id<NSTextContentManagerDelegate> _delegate;
    NSMutableArray *_textLayoutManagers;
    NSTextLayoutManager *_primaryTextLayoutManager;
    BOOL _hasEditingTransaction;
    BOOL _automaticallySynchronizesTextLayoutManagers;
    BOOL _automaticallySynchronizesToBackingStore;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _textLayoutManagers = [NSMutableArray array];
        _automaticallySynchronizesTextLayoutManagers = YES;   /* measured */
        _automaticallySynchronizesToBackingStore = NO;        /* measured */
    }
    return self;
}

- (id<NSTextContentManagerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSTextContentManagerDelegate>)d { _delegate = d; }
- (NSArray *)textLayoutManagers { return [_textLayoutManagers copy]; }
- (NSTextLayoutManager *)primaryTextLayoutManager { return _primaryTextLayoutManager; }
- (void)setPrimaryTextLayoutManager:(NSTextLayoutManager *)m
{
    _primaryTextLayoutManager = m;
    if (m && ![_textLayoutManagers containsObject:m]) [_textLayoutManagers addObject:m];
}
- (BOOL)hasEditingTransaction { return _hasEditingTransaction; }
- (BOOL)automaticallySynchronizesTextLayoutManagers { return _automaticallySynchronizesTextLayoutManagers; }
- (void)setAutomaticallySynchronizesTextLayoutManagers:(BOOL)v { _automaticallySynchronizesTextLayoutManagers = v; }
- (BOOL)automaticallySynchronizesToBackingStore { return _automaticallySynchronizesToBackingStore; }
- (void)setAutomaticallySynchronizesToBackingStore:(BOOL)v { _automaticallySynchronizesToBackingStore = v; }

- (NSTextRange *)documentRange { return nil; }   /* subclass provides (stage2) */

- (void)addTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    if (!textLayoutManager || [_textLayoutManagers containsObject:textLayoutManager]) return;
    [_textLayoutManagers addObject:textLayoutManager];
    /* TODO(stage2): set textLayoutManager.textContentManager = self and
       synchronize it with the current contents. primaryTextLayoutManager is NOT
       auto-assigned here (measured). */
}

- (void)removeTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    [_textLayoutManagers removeObject:textLayoutManager];
    if (_primaryTextLayoutManager == textLayoutManager) _primaryTextLayoutManager = nil;
}

- (void)performEditingTransactionUsingBlock:(void (NS_NOESCAPE ^)(void))transaction
{
    BOOL wasInTransaction = _hasEditingTransaction;
    _hasEditingTransaction = YES;
    if (transaction) transaction();
    _hasEditingTransaction = wasInTransaction;   /* supports nesting */
}

- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    return @[];   /* subclass provides the real elements (stage2) */
}

@end

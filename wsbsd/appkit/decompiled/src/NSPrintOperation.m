/*
 * NSPrintOperation.m — behavioral-1:1 core. See the header.
 */

#import "NSPrintOperation.h"

static NSString *const kCurrentOpKey = @"NSPrintOperation.current";

@implementation NSPrintOperation {
    NSView *_view;
    NSPrintInfo *_printInfo;
    NSString *_jobTitle;
    BOOL _showsPrintPanel;
    BOOL _showsProgressPanel;
    BOOL _canSpawnSeparateThread;
    NSPrintingPageOrder _pageOrder;
}

+ (instancetype)printOperationWithView:(NSView *)view
{
    return [self printOperationWithView:view printInfo:[[NSPrintInfo sharedPrintInfo] copy]];
}

+ (instancetype)printOperationWithView:(NSView *)view printInfo:(NSPrintInfo *)printInfo
{
    NSPrintOperation *op = [[self alloc] init];
    op->_view = view;
    op->_printInfo = [printInfo copy] ?: [[NSPrintInfo alloc] initWithDictionary:nil];
    op->_showsPrintPanel = YES;                 /* measured */
    op->_showsProgressPanel = YES;              /* measured */
    op->_pageOrder = NSAscendingPageOrder;      /* measured */
    /* jobTitle=nil, canSpawnSeparateThread=NO (measured) */
    return op;
}

+ (NSPrintOperation *)currentOperation
{
    /* thread-local; nil outside a run (measured). */
    return [[NSThread currentThread] threadDictionary][kCurrentOpKey];
}

+ (void)setCurrentOperation:(NSPrintOperation *)operation
{
    NSMutableDictionary *td = [[NSThread currentThread] threadDictionary];
    if (operation) td[kCurrentOpKey] = operation;
    else [td removeObjectForKey:kCurrentOpKey];
}

- (NSString *)jobTitle { return _jobTitle; }
- (void)setJobTitle:(NSString *)t { _jobTitle = [t copy]; }
- (BOOL)showsPrintPanel { return _showsPrintPanel; }
- (void)setShowsPrintPanel:(BOOL)v { _showsPrintPanel = v; }
- (BOOL)showsProgressPanel { return _showsProgressPanel; }
- (void)setShowsProgressPanel:(BOOL)v { _showsProgressPanel = v; }
- (BOOL)canSpawnSeparateThread { return _canSpawnSeparateThread; }
- (void)setCanSpawnSeparateThread:(BOOL)v { _canSpawnSeparateThread = v; }
- (NSPrintingPageOrder)pageOrder { return _pageOrder; }
- (void)setPageOrder:(NSPrintingPageOrder)o { _pageOrder = o; }
- (NSView *)view { return _view; }
- (NSPrintInfo *)printInfo { return _printInfo; }
- (void)setPrintInfo:(NSPrintInfo *)pi { _printInfo = [pi copy]; }
- (BOOL)isCopyingOperation { return NO; }   /* measured for a print operation */

@end

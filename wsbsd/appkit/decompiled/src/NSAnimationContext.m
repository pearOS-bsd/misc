/*
 * NSAnimationContext.m — 1:1 (core). See NSAnimationContext.h for the evidence.
 *
 * The contexts form a per-thread stack. currentContext returns the top; if the
 * stack is empty it seeds a base context (duration 0.25, AppKit's default).
 * beginGrouping pushes a new context inheriting the current duration;
 * endGrouping pops it and fires its completionHandler. runAnimationGroup: does
 * begin → changes(currentContext) → end. Core Animation / implicit-animation
 * driving is stage2.
 */
#import "NSAnimationContext.h"

static NSString * const kNSAnimationContextStack = @"NSAnimationContext.stack";

@implementation NSAnimationContext {
    NSTimeInterval _duration;
    void (^_completionHandler)(void);
    BOOL _allowsImplicitAnimation;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _duration = 0.25; }   /* AppKit default animation duration */
    return self;
}

+ (NSMutableArray<NSAnimationContext *> *)_stack
{
    NSMutableDictionary *td = [NSThread currentThread].threadDictionary;
    NSMutableArray *s = td[kNSAnimationContextStack];
    if (!s) { s = [NSMutableArray array]; td[kNSAnimationContextStack] = s; }
    return s;
}

+ (NSAnimationContext *)currentContext
{
    NSMutableArray *s = [self _stack];
    if (s.count == 0) [s addObject:[[NSAnimationContext alloc] init]]; /* base context */
    return s.lastObject;
}

+ (void)beginGrouping
{
    NSAnimationContext *parent = [self currentContext];
    NSAnimationContext *ctx = [[NSAnimationContext alloc] init];
    ctx->_duration = parent->_duration;   /* inherit the current duration */
    [[self _stack] addObject:ctx];
}

+ (void)endGrouping
{
    NSMutableArray *s = [self _stack];
    if (s.count == 0) return;
    NSAnimationContext *ctx = s.lastObject;
    [s removeLastObject];
    if (ctx->_completionHandler) ctx->_completionHandler();  /* animations are
                                                              * synchronous here */
}

+ (void)runAnimationGroup:(void (NS_NOESCAPE ^)(NSAnimationContext *))changes
{
    [self beginGrouping];
    if (changes) changes([self currentContext]);
    [self endGrouping];
}

+ (void)runAnimationGroup:(void (NS_NOESCAPE ^)(NSAnimationContext *))changes
        completionHandler:(void (^)(void))completionHandler
{
    [self beginGrouping];
    [self currentContext].completionHandler = completionHandler;
    if (changes) changes([self currentContext]);
    [self endGrouping];
}

- (NSTimeInterval)duration { return _duration; }
- (void)setDuration:(NSTimeInterval)v { _duration = v; }
- (void (^)(void))completionHandler { return _completionHandler; }
- (void)setCompletionHandler:(void (^)(void))h { _completionHandler = [h copy]; }
- (BOOL)allowsImplicitAnimation { return _allowsImplicitAnimation; }
- (void)setAllowsImplicitAnimation:(BOOL)v { _allowsImplicitAnimation = v; }

@end

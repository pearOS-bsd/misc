/* CATransaction: the stack of transactions of a thread. Layer changes made outside an explicit transaction belong to the implicit transaction, which the run loop commits. */
#import "CALayerPrivate.h"

NSString *const kCATransactionAnimationDuration = @"animationDuration";
NSString *const kCATransactionDisableActions = @"disableActions";
NSString *const kCATransactionAnimationTimingFunction = @"animationTimingFunction";
NSString *const kCATransactionCompletionBlock = @"completionBlock";

@interface CATransactionState : NSObject
{ @public
	NSMutableDictionary *values;
	CFTimeInterval time;                       /* 0 until first needed */
	BOOL implicit, flushScheduled;
	NSInteger pending;                         /* animations started inside the transaction that have not finished */
}
@end
@implementation CATransactionState
- (instancetype)init { if ((self = [super init])) { values = [NSMutableDictionary new]; } return self; }
@end

static NSMutableArray *stack(void)
{
	NSMutableDictionary *td = [[NSThread currentThread] threadDictionary];
	NSMutableArray *s = td[@"CATransactionStack"];
	if (!s) { s = [NSMutableArray new]; td[@"CATransactionStack"] = s; }
	return s;
}
static CATransactionState *top(void)
{
	NSMutableArray *s = stack();
	if (!s.count) { CATransactionState *t = [CATransactionState new]; t->implicit = YES; [s addObject:t]; }
	return s.lastObject;
}

CFTimeInterval CATransactionTime(void)
{
	CATransactionState *t = top();
	if (t->time == 0) t->time = CACurrentMediaTime();
	return t->time;
}

/* a layer changed: the implicit transaction is committed by the run loop */
void CATransactionNoteChange(void)
{
	CATransactionState *t = top();
	if (t->implicit && !t->flushScheduled) {
		t->flushScheduled = YES;
		[[NSRunLoop mainRunLoop] performSelector:@selector(_wsbsdFlushImplicit) target:[CATransaction class] argument:nil order:0 modes:@[NSRunLoopCommonModes]];
	}
}

@implementation CATransaction
+ (void)_wsbsdFlushImplicit { [self flush]; }
+ (void)begin
{
	CATransactionState *parent = top(), *t = [CATransactionState new];
	[t->values addEntriesFromDictionary:parent->values];            /* a nested transaction starts from the settings of its parent */
	[stack() addObject:t];
}
+ (void)commit
{
	NSMutableArray *s = stack();
	if (s.count < 2 || ((CATransactionState *)s.lastObject)->implicit) { [self flush]; return; }
	CATransactionState *t = s.lastObject; [s removeLastObject];
	[self _finish:t];
}
+ (void)_finish:(CATransactionState *)t
{
	void (^b)(void) = t->values[kCATransactionCompletionBlock];
	if (b) b();
	CALayerCommitAnimations();
}
+ (void)flush
{
	NSMutableArray *s = stack();
	CATransactionState *t = s.firstObject;
	if (t && t->implicit) { [s removeObjectAtIndex:0]; [self _finish:t]; }
	else CALayerCommitAnimations();
}
+ (void)lock {}
+ (void)unlock {}
+ (CFTimeInterval)animationDuration { NSNumber *n = top()->values[kCATransactionAnimationDuration]; return n ? [n doubleValue] : 0.25; }
+ (void)setAnimationDuration:(CFTimeInterval)d { top()->values[kCATransactionAnimationDuration] = @(d); CATransactionNoteChange(); }
+ (CAMediaTimingFunction *)animationTimingFunction { return top()->values[kCATransactionAnimationTimingFunction]; }
+ (void)setAnimationTimingFunction:(CAMediaTimingFunction *)f { if (f) top()->values[kCATransactionAnimationTimingFunction] = f; else [top()->values removeObjectForKey:kCATransactionAnimationTimingFunction]; }
+ (BOOL)disableActions { return [top()->values[kCATransactionDisableActions] boolValue]; }
+ (void)setDisableActions:(BOOL)f { top()->values[kCATransactionDisableActions] = @(f); }
+ (void (^)(void))completionBlock { return top()->values[kCATransactionCompletionBlock]; }
+ (void)setCompletionBlock:(void (^)(void))b { if (b) top()->values[kCATransactionCompletionBlock] = [b copy]; else [top()->values removeObjectForKey:kCATransactionCompletionBlock]; }
+ (id)valueForKey:(NSString *)key { return top()->values[key]; }
+ (void)setValue:(id)v forKey:(NSString *)key { if (v) top()->values[key] = v; else [top()->values removeObjectForKey:key]; }
@end

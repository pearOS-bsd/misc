/* OpenBindings.m — Cocoa bindings on NSObject (the category AppKit adds): bind:toObject:withKeyPath:options: keeps the bound property of the receiver in step with a key path of the other object (one way: model -> view; the reverse when the view calls -setValue:forKey: is left to the control) */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface OpenBinding : NSObject { @public __weak id target; NSString *binding; id obj; NSString *kp; } @end
@implementation OpenBinding
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)x { [self push]; }
- (void)push { id v = [obj valueForKeyPath:kp]; if (v == NSNull.null) v = nil; @try { [target setValue:v forKey:binding]; } @catch (NSException *e) { } }
@end

static char kBindings;
@implementation NSObject (OpenBindings)
- (void)bind:(NSString *)binding toObject:(id)o withKeyPath:(NSString *)kp options:(NSDictionary *)opts
{
    NSMutableDictionary *m = objc_getAssociatedObject(self, &kBindings); if (!m) { m = [NSMutableDictionary new]; objc_setAssociatedObject(self, &kBindings, m, OBJC_ASSOCIATION_RETAIN); }
    [self unbind:binding];
    OpenBinding *b = [OpenBinding new]; b->target = self; b->binding = [binding copy]; b->obj = o; b->kp = [kp copy]; m[binding] = b;
    @try { [o addObserver:b forKeyPath:kp options:0 context:NULL]; } @catch (NSException *e) { }
    [b push];
}
- (void)unbind:(NSString *)binding
{
    NSMutableDictionary *m = objc_getAssociatedObject(self, &kBindings); OpenBinding *b = m[binding]; if (!b) return;
    @try { [b->obj removeObserver:b forKeyPath:b->kp]; } @catch (NSException *e) { }
    [m removeObjectForKey:binding];
}
- (NSDictionary *)infoForBinding:(NSString *)binding { return nil; }
+ (void)exposeBinding:(NSString *)b { }
- (NSArray *)exposedBindings { return @[]; }
@end

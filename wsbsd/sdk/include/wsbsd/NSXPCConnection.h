/* NSXPCConnection of gnustep-base raises "not implemented" in every method; sdk/src/XPC.m implements them over a unix socket per service (WSBSD_XPC_DIR, default /var/run/xpc).
 * This header only adds what the base header lacks (the setters and extras of the Apple API). Dot syntax works through the declared accessor pairs. */
#import <Foundation/Foundation.h>
#import <Foundation/NSXPCConnection.h>
@interface NSXPCConnection (WsbsdXPCAPI)
- (id)exportedObject;
- (void)setExportedObject:(id)object;
- (void)setExportedInterface:(NSXPCInterface *)ifc;
- (void)scheduleSendBarrierBlock:(void (^)(void))block;
+ (NSXPCConnection *)currentConnection;
@end
@interface NSXPCListenerEndpoint (WsbsdPath)
- (NSString *)wsbsdPath;
- (void)setWsbsdPath:(NSString *)path;
@end
#ifdef __cplusplus
extern "C" {
#endif
/* adds to cls a method for every instance method of the protocol (and the protocols it adopts) that cls lacks: it calls the reply block, if the method has one, with zeroed arguments */
void WsbsdXPCInstallDefaultReplies(Class cls, Protocol *proto);
#ifdef __cplusplus
}
#endif

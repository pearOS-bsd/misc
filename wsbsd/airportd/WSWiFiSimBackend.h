#import <wsbsd/WSAirport.h>
@interface WSWiFiSimBackend : NSObject <WSWiFiBackend>
- (instancetype)initWithWorld:(NSDictionary *)world;
+ (NSDictionary *)builtInWorld;
+ (NSDictionary *)recordForNetwork:(NSDictionary *)network;
@end

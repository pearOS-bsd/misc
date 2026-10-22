#import <wsbsd/WSAirport.h>
/* airportd: serves the CoreWLAN requests, keeps the known networks (/Library/Preferences/com.apple.wifi.known-networks.plist, or WSBSD_AIRPORT_PREFS), joins them on its own (auto-join) and tells the
 * clients that asked about the changes of the interfaces. */
@interface WSAirportService : NSObject <WSAirportXPCRequests, NSXPCListenerDelegate>
- (instancetype)initWithBackend:(id<WSWiFiBackend>)backend preferences:(NSString *)path;
- (void)startListening;                       /* the mach services of the real airportd: com.apple.corewlan-xpc and com.apple.airportd */
- (void)stopListening;
@property (nonatomic) BOOL autoJoinEnabled;
- (void)autoJoinAll;                          /* one auto-join pass over the interfaces (it runs on its own at start, when power comes on, when a link is lost and when a profile is added) */
@end

#import <wsbsd/WSAirport.h>
/* The real thing: wpa_supplicant's control interface (/var/run/wpa_supplicant/<interface>, WSBSD_WPA_CTRL) for state, scan, join and events, ifconfig(8) for power, address and channels. */
@interface WSWiFiWpaBackend : NSObject <WSWiFiBackend>
- (instancetype)initWithControlDirectory:(NSString *)dir ifconfig:(NSString *)ifconfig;
@end

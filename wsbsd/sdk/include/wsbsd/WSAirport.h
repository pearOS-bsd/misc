/* The contract between CoreWLAN (client) and airportd (the daemon), over NSXPCConnection (sdk/src/XPC.m). The requests are the ones of the real protocols (CWFXPCRequestProtocol*, CWWiFiXPCRequestProtocol),
 * the events those of CWWiFiXPCEventProtocol; the reply values are the ones fixed here (the block types of this file are what both sides use). Services (launchd MachServices of the real airportd):
 * com.apple.airportd and com.apple.corewlan-xpc, both answered by the same exported object. */
#import <Foundation/Foundation.h>
#import <CoreWiFi/CoreWiFi_Generated.h>
#import <CoreWLAN/CoreWLANTypes.h>
#import <CoreWLAN/CoreWLAN_Generated.h>
#import <wsbsd/NSXPCConnection.h>
#ifdef __cplusplus
extern "C" {
#endif
extern NSString *const WSAirportServiceCoreWLAN;   /* com.apple.corewlan-xpc */
extern NSString *const WSAirportServiceAirportd;   /* com.apple.airportd */
/* reply blocks: the first argument is an NSError (nil on success) */
typedef void (^WSReplyVoid)(NSError *error);
typedef void (^WSReplyObject)(NSError *error, id value);
typedef void (^WSReplyInteger)(NSError *error, long long value);
typedef void (^WSReplyBool)(NSError *error, BOOL value);
typedef void (^WSReplyDouble)(NSError *error, double value);
@protocol WSAirportXPCRequests <CWFXPCRequestProtocolCoreWLAN, CWFXPCRequestProtocolPublicWiFi, CWFXPCRequestProtocolUnrestricted, CWWiFiXPCRequestProtocol>
@end
@protocol WSAirportXPCEvents <CWWiFiXPCEventProtocol>
@end
/* keys of the state dictionary of an interface (WSWiFiBackend) */
extern NSString *const WSWiFiStatePower, *const WSWiFiStateSSID, *const WSWiFiStateBSSID, *const WSWiFiStateChannel, *const WSWiFiStateChannelFlags, *const WSWiFiStateRSSI, *const WSWiFiStateNoise,
	*const WSWiFiStateTxRate, *const WSWiFiStateMAC, *const WSWiFiStateCountry, *const WSWiFiStateLinkUp, *const WSWiFiStateScanRecord, *const WSWiFiStateOpMode;
/* the Wi-Fi hardware (or the simulation of it) airportd drives */
@protocol WSWiFiBackend <NSObject>
- (NSArray<NSString *> *)interfaceNames;
- (NSDictionary *)stateForInterface:(NSString *)name;
- (BOOL)setPower:(BOOL)on forInterface:(NSString *)name error:(NSError **)error;
/* scan records (the dictionaries of Apple80211: SSID, BSSID, CHANNEL, CHANNEL_FLAGS, RSSI, IE, RSN_IE ...) */
- (NSArray<NSDictionary *> *)scanInterface:(NSString *)name ssid:(NSData *)ssid error:(NSError **)error;
- (BOOL)associateInterface:(NSString *)name toRecord:(NSDictionary *)record password:(NSString *)password error:(NSError **)error;
- (void)disassociateInterface:(NSString *)name;
- (NSArray<NSNumber *> *)supportedChannelsForInterface:(NSString *)name;
@property (copy) void (^eventHandler)(NSString *event, NSString *interfaceName, NSDictionary *info);   /* "power", "ssid", "bssid", "link", "linkQuality", "countryCode", "mode", "scanCache" */
@end
#ifdef __cplusplus
}
#endif

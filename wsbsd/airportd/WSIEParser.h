#import <Foundation/Foundation.h>
/* Information elements of a beacon / probe response -> the keys of an Apple80211 scan record that CWNetwork reads (RSN_IE, WPA_IE, IOS_IE, HT_CAPS_IE, VHT_CAPS, HE_CAP, 80211D_IE, 11U_INTERWORKING_IE, HOTSPOT20_IE,
 * WPS_BEACON_IE, APPLE_DEVICE_IE ...). The data is the raw IE bytes (id, length, body ...). */
@interface WSIEParser : NSObject
+ (NSDictionary *)scanRecordKeysForIEData:(NSData *)ie;
+ (NSString *)SSIDStringForData:(NSData *)ssid;
@end

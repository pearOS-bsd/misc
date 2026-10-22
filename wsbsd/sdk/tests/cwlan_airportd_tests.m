/* CoreWLAN against airportd (simulated Wi-Fi world, in one process): interfaces, power, scan and hotspot detection, joining with a wrong and a right password, events, remembered networks, auto-join. */
#import <wsbsd/WSAirport.h>
#import "WSAirportService.h"
#import "WSWiFiSimBackend.h"
#include <stdio.h>
static int failures; static void Check(int ok, const char *what, int line) { if (!ok) { printf("FAIL %s:%d %s\n", __FILE__, line, what); failures++; } }
#define CHECK(c) Check((c), #c, __LINE__)
#define STEP(n) fprintf(stderr, "step %d\n", n)
@interface Delegate : NSObject <CWEventDelegate> { @public NSMutableArray *events; } @end
@implementation Delegate
- (instancetype)init { if ((self = [super init])) events = [NSMutableArray array]; return self; }
- (void)ssidDidChangeForWiFiInterfaceWithName:(NSString *)n { @synchronized (self) { [events addObject: @"ssid"]; } }
- (void)bssidDidChangeForWiFiInterfaceWithName:(NSString *)n { @synchronized (self) { [events addObject: @"bssid"]; } }
- (void)linkDidChangeForWiFiInterfaceWithName:(NSString *)n { @synchronized (self) { [events addObject: @"link"]; } }
- (void)powerStateDidChangeForWiFiInterfaceWithName:(NSString *)n { @synchronized (self) { [events addObject: @"power"]; } }
@end
static BOOL Wait(BOOL (^cond)(void)) { for (int i = 0; i < 200; i++) { if (cond()) return YES; usleep(25000); } return NO; }
int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	@autoreleasepool {
		setenv("WSBSD_XPC_DIR", "/tmp/wsbsd-airportd-test", 1); NSString *prefs = @"/tmp/wsbsd-airportd-test-known.plist"; [[NSFileManager defaultManager] removeItemAtPath: prefs error: nil];
		WSWiFiSimBackend *backend = [[WSWiFiSimBackend alloc] initWithWorld: nil]; WSAirportService *svc = [[WSAirportService alloc] initWithBackend: backend preferences: prefs]; [svc setAutoJoinEnabled: NO]; [svc startListening];
		CWWiFiClient *client = [[CWWiFiClient alloc] init]; Delegate *del = [Delegate new]; [client setDelegate: del];
		CHECK([[client interfaceNames] isEqualToArray: @[ @"en0" ]]);
		CWInterface *wifi = [client interface]; CHECK(wifi != nil); CHECK([[wifi interfaceName] isEqualToString: @"en0"]); CHECK([client interfaceWithName: @"en99"] == nil);
		CHECK([wifi powerOn]); CHECK([wifi ssid] == nil); CHECK([wifi hardwareAddress] != nil); CHECK([[wifi hardwareAddress] isEqualToString: @"02:57:53:00:00:01"]); CHECK([[wifi countryCode] isEqualToString: @"US"]); CHECK([wifi interfaceMode] == kCWInterfaceModeStation);
		NSError *e = nil; CHECK([client startMonitoringEventWithType: CWEventTypeSSIDDidChange error: &e]); CHECK([client startMonitoringEventWithType: CWEventTypeLinkDidChange error: &e]); CHECK([client startMonitoringEventWithType: CWEventTypePowerDidChange error: &e]);
		NSSet *nets = [wifi scanForNetworksWithName: nil error: &e]; CHECK([nets count] == 5); CHECK(e == nil);
		CWNetwork *home = nil, *phone = nil, *cafe = nil; for (CWNetwork *n in nets) { if ([[n ssid] isEqualToString: @"Home"] && [[n wlanChannel] channelNumber] == 6) home = n; if ([n isPersonalHotspot]) phone = n; if ([[n ssid] isEqualToString: @"Cafe"]) cafe = n; }
		CHECK(home && phone && cafe); CHECK([phone isPersonalHotspot]); CHECK(![home isPersonalHotspot]); CHECK([[phone ssid] isEqualToString: @"Alex's iPhone"]); CHECK([cafe isOpen]); CHECK([home supportsSecurity: kCWSecurityWPA2Personal]); CHECK([[home wlanChannel] channelBand] == kCWChannelBand2GHz);
		CHECK([[wifi scanForNetworksWithName: @"Cafe" error: &e] count] == 1); CHECK([[wifi scanForNetworksWithName: @"nothing" error: &e] count] == 0);
		CHECK(![wifi associateToNetwork: home password: @"wrong" error: &e]); CHECK(e != nil && [[e domain] isEqualToString: @"com.apple.wifi.apple80211API.error"] && [e code] == -3900); CHECK([wifi ssid] == nil);
		e = nil; CHECK([wifi associateToNetwork: home password: @"homepass" error: &e]); CHECK(e == nil);
		CHECK([[wifi ssid] isEqualToString: @"Home"]); CHECK([[wifi bssid] isEqualToString: @"02:11:22:33:44:01"]); CHECK([wifi rssiValue] == -48); CHECK([[wifi wlanChannel] channelNumber] == 6); CHECK([wifi noiseMeasurement] == -92); CHECK([wifi transmitRate] > 100); CHECK([wifi security] == kCWSecurityWPA2Personal);
		CHECK([[[wifi lastNetworkJoined] ssid] isEqualToString: @"Home"]); CHECK([wifi activePHYMode] == kCWPHYMode11ac);
		CHECK(Wait(^BOOL{ @synchronized (del) { return [del->events containsObject: @"ssid"] && [del->events containsObject: @"link"]; } }));
		CWConfiguration *cfg = [wifi configuration]; CHECK([[cfg networkProfiles] count] == 1); CWNetworkProfile *prof = [[cfg networkProfiles] firstObject]; CHECK([[prof ssid] isEqualToString: @"Home"]); CHECK([prof security] != kCWSecurityNone);
		[wifi disassociate]; CHECK(Wait(^BOOL{ return [wifi ssid] == nil; }));
		CHECK([wifi setPower: NO error: &e]); CHECK(![wifi powerOn]); CHECK([wifi scanForNetworksWithName: nil error: &e] == nil && e != nil); CHECK(Wait(^BOOL{ @synchronized (del) { return [del->events containsObject: @"power"]; } }));
		CHECK([wifi setPower: YES error: &e]); CHECK([wifi powerOn]);
		/* a new daemon with the same preferences joins the known network on its own, and a hotspot only when nothing else is known and in range */
		[svc stopListening]; WSWiFiSimBackend *b2 = [[WSWiFiSimBackend alloc] initWithWorld: nil]; WSAirportService *svc2 = [[WSAirportService alloc] initWithBackend: b2 preferences: prefs]; [svc2 startListening];
		CWWiFiClient *c2 = [[CWWiFiClient alloc] init]; CWInterface *w2 = [c2 interface]; CHECK(Wait(^BOOL{ return [[w2 ssid] isEqualToString: @"Home"]; })); fprintf(stderr, "w2 ssid=%s power=%d names=%s\n", [[w2 ssid] UTF8String] ?: "(nil)", [w2 powerOn], [[[c2 interfaceNames] description] UTF8String]);
		[w2 disassociate]; NSMutableArray *profiles = [NSMutableArray arrayWithContentsOfFile: prefs]; [profiles removeAllObjects]; [profiles addObject: @{ @"ssid": [@"Alex's iPhone" dataUsingEncoding: NSUTF8StringEncoding], @"securityType": @128, @"password": @"hotspot123" }];
		[profiles writeToFile: prefs atomically: YES]; [svc2 stopListening]; WSAirportService *svc3 = [[WSAirportService alloc] initWithBackend: [[WSWiFiSimBackend alloc] initWithWorld: nil] preferences: prefs]; [svc3 startListening];
		CWWiFiClient *c3 = [[CWWiFiClient alloc] init]; CHECK(Wait(^BOOL{ return [[[c3 interface] ssid] isEqualToString: @"Alex's iPhone"]; })); CHECK([[[c3 interface] lastNetworkJoined] isPersonalHotspot]);
		[svc3 stopListening];
	}
	printf(failures ? "cwlan_airportd_tests: %d failures\n" : "cwlan_airportd_tests: ok\n", failures); return failures != 0;
}

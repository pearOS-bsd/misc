/* airportd: /usr/libexec/airportd. WSBSD_WIFI_BACKEND=sim (the simulated world) or wpa (wpa_supplicant, default when /var/run/wpa_supplicant exists). */
#import "WSAirportService.h"
#import "WSWiFiSimBackend.h"
int main(int argc, char **argv)
{
	@autoreleasepool {
		id<WSWiFiBackend> backend = [[WSWiFiSimBackend alloc] init];
		WSAirportService *svc = [[WSAirportService alloc] initWithBackend: backend preferences: @(getenv("WSBSD_AIRPORT_PREFS") ?: "/Library/Preferences/com.apple.wifi.known-networks.plist")];
		[svc startListening]; [[NSRunLoop currentRunLoop] run];
	}
	return 0;
}

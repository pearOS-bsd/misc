/* airportd: /usr/libexec/airportd. WSBSD_WIFI_BACKEND=sim (the simulated world) or wpa (wpa_supplicant, default when /var/run/wpa_supplicant exists). */
#import "WSAirportService.h"
#import "WSWiFiSimBackend.h"
#import "WSWiFiWpaBackend.h"
#include <sys/stat.h>
int main(int argc, char **argv)
{
	@autoreleasepool {
		const char *kind = getenv("WSBSD_WIFI_BACKEND"); struct stat st; const char *ctrl = getenv("WSBSD_WPA_CTRL") ?: "/var/run/wpa_supplicant";
		BOOL wpa = kind ? strcmp(kind, "wpa") == 0 : stat(ctrl, &st) == 0;
		id<WSWiFiBackend> backend = wpa ? [[WSWiFiWpaBackend alloc] initWithControlDirectory: @(ctrl) ifconfig: @"/sbin/ifconfig"] : [[WSWiFiSimBackend alloc] init];
		WSAirportService *svc = [[WSAirportService alloc] initWithBackend: backend preferences: @(getenv("WSBSD_AIRPORT_PREFS") ?: "/Library/Preferences/com.apple.wifi.known-networks.plist")];
		[svc startListening]; [[NSRunLoop currentRunLoop] run];
	}
	return 0;
}

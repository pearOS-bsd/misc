/* airportd: /usr/libexec/airportd. WSBSD_WIFI_BACKEND=sim (the simulated world, for tests) or wpa (wpa_supplicant, the default; no interfaces while /var/run/wpa_supplicant is missing). */
#import "WSAirportService.h"
#import "WSWiFiSimBackend.h"
#import "WSWiFiWpaBackend.h"
#include <sys/stat.h>
int main(int argc, char **argv)
{
	@autoreleasepool {
		const char *kind = getenv("WSBSD_WIFI_BACKEND"); struct stat st; const char *ctrl = getenv("WSBSD_WPA_CTRL") ?: "/var/run/wpa_supplicant";
		BOOL wpa = !(kind && strcmp(kind, "sim") == 0); (void)st;
		id<WSWiFiBackend> backend = wpa ? [[WSWiFiWpaBackend alloc] initWithControlDirectory: @(ctrl) ifconfig: @"/sbin/ifconfig"] : [[WSWiFiSimBackend alloc] init];
		WSAirportService *svc = [[WSAirportService alloc] initWithBackend: backend preferences: @(getenv("WSBSD_AIRPORT_PREFS") ?: "/Library/Preferences/com.apple.wifi.known-networks.plist")];
		[svc startListening]; [[NSRunLoop currentRunLoop] run];
	}
	return 0;
}

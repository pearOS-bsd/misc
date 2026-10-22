/* WSWiFiWpaBackend against a fake wpa_supplicant (datagram control socket) and a fake ifconfig; WSIEParser on hand-built IEs. */
#import <Foundation/Foundation.h>
#import <wsbsd/WSAirport.h>
#import "WSIEParser.h"
#import "WSWiFiWpaBackend.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <pthread.h>
#include <poll.h>
#include <unistd.h>

static int fails;
#define CHECK(c, ...) do { if (!(c)) { fails++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

static NSString *HexOf(const unsigned char *b, size_t n) { NSMutableString *s = [NSMutableString string]; for (size_t i = 0; i < n; i++) [s appendFormat: @"%02x", b[i]]; return s; }
static int sfd; static struct sockaddr_un attached; static socklen_t attachedLen; static int connected, wrongKey;

static void Reply(struct sockaddr_un *to, socklen_t tl, NSString *s) { sendto(sfd, [s UTF8String], strlen([s UTF8String]), 0, (struct sockaddr *)to, tl); }
static void Event(NSString *s) { if (attachedLen) Reply(&attached, attachedLen, s); }

static void *Serve(void *arg)
{
	/* beacon IEs: SSID "Alex's iPhone", RSN (CCMP, PSK), vendor Apple iOS IE 00:17:f2:06 */
	static const unsigned char ssid[] = "Alex's iPhone"; unsigned char ie[256]; size_t n = 0;
	ie[n++] = 0; ie[n++] = 13; memcpy(ie + n, ssid, 13); n += 13;
	const unsigned char rsn[] = { 1, 0, 0x00, 0x0f, 0xac, 4, 1, 0, 0x00, 0x0f, 0xac, 4, 1, 0, 0x00, 0x0f, 0xac, 2, 0, 0 };
	ie[n++] = 48; ie[n++] = sizeof rsn; memcpy(ie + n, rsn, sizeof rsn); n += sizeof rsn;
	const unsigned char ios[] = { 0x00, 0x17, 0xf2, 0x06, 0x01, 0x01, 0x03, 0x01, 0, 0, 0 };
	ie[n++] = 221; ie[n++] = sizeof ios; memcpy(ie + n, ios, sizeof ios); n += sizeof ios;
	NSString *ieHex = HexOf(ie, n);
	for (;;) {
		struct pollfd p = { .fd = sfd, .events = POLLIN }; if (poll(&p, 1, 200) <= 0) continue;
		char buf[2048]; struct sockaddr_un from; socklen_t fl = sizeof from; ssize_t k = recvfrom(sfd, buf, sizeof buf - 1, 0, (struct sockaddr *)&from, &fl); if (k <= 0) continue; buf[k] = 0; NSString *c = @(buf);
		if ([c isEqual: @"QUIT"]) break;
		if ([c isEqual: @"ATTACH"]) { attached = from; attachedLen = fl; Reply(&from, fl, @"OK\n"); }
		else if ([c isEqual: @"STATUS"]) Reply(&from, fl, connected ? @"bssid=02:00:00:00:00:01\nfreq=2437\nssid=Alex's iPhone\nwpa_state=COMPLETED\naddress=aa:bb:cc:dd:ee:ff\n" : @"wpa_state=DISCONNECTED\naddress=aa:bb:cc:dd:ee:ff\n");
		else if ([c isEqual: @"SIGNAL_POLL"]) Reply(&from, fl, @"RSSI=-51\nLINKSPEED=144\nNOISE=-95\n");
		else if ([c isEqual: @"SCAN"]) { Reply(&from, fl, @"OK\n"); Event(@"<3>CTRL-EVENT-SCAN-RESULTS "); }
		else if ([c isEqual: @"SCAN_RESULTS"]) Reply(&from, fl, @"bssid / frequency / signal level / flags / ssid\n02:00:00:00:00:01\t2437\t-51\t[WPA2-PSK-CCMP][ESS]\tAlex's iPhone\n");
		else if ([c hasPrefix: @"BSS "]) Reply(&from, fl, [NSString stringWithFormat: @"bssid=02:00:00:00:00:01\nfreq=2437\nbeacon_int=100\nie=%@\n", ieHex]);
		else if ([c hasPrefix: @"SET_NETWORK"]) { wrongKey = [c containsString: @"psk \"bad\""]; Reply(&from, fl, @"OK\n"); }
		else if ([c isEqual: @"ADD_NETWORK"]) Reply(&from, fl, @"0\n");
		else if ([c hasPrefix: @"SELECT_NETWORK"]) { Reply(&from, fl, @"OK\n"); if (wrongKey) Event(@"<3>CTRL-EVENT-SSID-TEMP-DISABLED id=0 ssid=\"x\" auth_failures=1 duration=10 reason=WRONG_KEY"); else { connected = 1; Event(@"<3>CTRL-EVENT-CONNECTED - Connection to 02:00:00:00:00:01 completed"); } }
		else if ([c isEqual: @"DISCONNECT"]) { connected = 0; Reply(&from, fl, @"OK\n"); Event(@"<3>CTRL-EVENT-DISCONNECTED bssid=02:00:00:00:00:01 reason=3"); }
		else Reply(&from, fl, @"OK\n");
	}
	return NULL;
}

int main(void)
{
	@autoreleasepool {
		/* WSIEParser */
		const unsigned char ies[] = { 0, 3, 'a', 'b', 'c', 221, 7, 0x00, 0x17, 0xf2, 0x06, 1, 1, 3, 221, 5, 0x00, 0x17, 0xf2, 0x09, 0 };
		NSDictionary *k = [WSIEParser scanRecordKeysForIEData: [NSData dataWithBytes: ies length: sizeof ies]];
		CHECK([k[@"SSID"] isEqual: [@"abc" dataUsingEncoding: NSUTF8StringEncoding]]);
		CHECK(k[@"IOS_IE"] != nil); CHECK(k[@"APPLE_DEVICE_IE"] != nil); CHECK(k[@"RSN_IE"] == nil);
		CHECK([[WSIEParser SSIDStringForData: [@"abc" dataUsingEncoding: NSUTF8StringEncoding]] isEqual: @"abc"]);

		/* backend vs fake supplicant */
		NSString *dir = @"/tmp/wsbsd-wpa-test"; [[NSFileManager defaultManager] removeItemAtPath: dir error: NULL]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
		sfd = socket(AF_UNIX, SOCK_DGRAM, 0); struct sockaddr_un a = { .sun_family = AF_UNIX }; snprintf(a.sun_path, sizeof a.sun_path, "%s/wlan0", [dir fileSystemRepresentation]); bind(sfd, (struct sockaddr *)&a, sizeof a);
		pthread_t t; pthread_create(&t, NULL, Serve, NULL);
		NSString *fake = [dir stringByAppendingPathComponent: @"ifconfig"]; [@"#!/bin/sh\necho 'wlan0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500'\necho '\tcountry RO authmode WPA2/802.11i'\n" writeToFile: fake atomically: YES encoding: NSUTF8StringEncoding error: NULL]; chmod([fake fileSystemRepresentation], 0755);
		WSWiFiWpaBackend *b = [[WSWiFiWpaBackend alloc] initWithControlDirectory: dir ifconfig: fake];
		CHECK([[b interfaceNames] isEqual: @[ @"wlan0" ]]);
		NSDictionary *st = [b stateForInterface: @"wlan0"]; CHECK([st[WSWiFiStatePower] boolValue]); CHECK(![st[WSWiFiStateLinkUp] boolValue]); CHECK([st[WSWiFiStateMAC] isEqual: @"aa:bb:cc:dd:ee:ff"]); CHECK([st[WSWiFiStateCountry] isEqual: @"RO"]);
		NSError *e = nil; NSArray *scan = [b scanInterface: @"wlan0" ssid: nil error: &e]; CHECK([scan count] == 1); NSDictionary *r = scan.firstObject;
		CHECK([r[@"SSID_STR"] isEqual: @"Alex's iPhone"]); CHECK([r[@"CHANNEL"] intValue] == 6); CHECK([r[@"RSSI"] intValue] == -51); CHECK(r[@"IOS_IE"] != nil); CHECK(r[@"RSN_IE"] != nil);
		CHECK(![b associateInterface: @"wlan0" toRecord: r password: @"bad" error: &e]); CHECK(e != nil);
		e = nil; CHECK([b associateInterface: @"wlan0" toRecord: r password: @"good" error: &e]);
		st = [b stateForInterface: @"wlan0"]; CHECK([st[WSWiFiStateLinkUp] boolValue]); CHECK([st[WSWiFiStateRSSI] intValue] == -51); CHECK(st[WSWiFiStateScanRecord][@"IOS_IE"] != nil);
		[b disassociateInterface: @"wlan0"]; usleep(200000); CHECK(![[b stateForInterface: @"wlan0"][WSWiFiStateLinkUp] boolValue]);
		int qc = socket(AF_UNIX, SOCK_DGRAM, 0); struct sockaddr_un ql = { .sun_family = AF_UNIX }; strcpy(ql.sun_path, "/tmp/wsbsd-wpa-quit"); unlink(ql.sun_path); bind(qc, (struct sockaddr *)&ql, sizeof ql);
		sendto(qc, "QUIT", 4, 0, (struct sockaddr *)&a, sizeof a); pthread_join(t, NULL); unlink(ql.sun_path);
		printf(fails ? "wpa_backend_tests: %d FAILED\n" : "wpa_backend_tests: ok\n", fails);
	}
	return fails != 0;
}

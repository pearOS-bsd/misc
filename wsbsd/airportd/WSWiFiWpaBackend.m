#import "WSWiFiWpaBackend.h"
#import "WSIEParser.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <pthread.h>
#include <unistd.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>

static NSError *Err(NSInteger code, NSString *why) { return [NSError errorWithDomain: @"com.apple.wifi.apple80211API.error" code: code userInfo: @{ NSLocalizedFailureReasonErrorKey: why ?: @"error" }]; }
static int ChannelForFreq(int f) { if (f == 2484) return 14; if (f >= 2412 && f < 2484) return (f - 2407) / 5; if (f >= 5955 && f <= 7115) return (f - 5950) / 5; if (f >= 5000 && f < 5955) return (f - 5000) / 5; return 0; }
static unsigned FlagsForFreq(int f) { return (f >= 5925 ? 0x2000 : f >= 4900 ? 0x10 : 0x8) | 0x2; }

/* ---- the control socket of wpa_supplicant ---- */
@interface WSWpaCtrl : NSObject { int _fd; NSString *_local; }
- (instancetype)initWithPath:(NSString *)path;
- (NSString *)request:(NSString *)cmd timeout:(double)t;
- (void)close;
@end
@implementation WSWpaCtrl
static int gCounter;
- (instancetype)initWithPath:(NSString *)path
{
	if ((self = [super init])) {
		_fd = socket(AF_UNIX, SOCK_DGRAM, 0); struct sockaddr_un l = { .sun_family = AF_UNIX }; _local = [NSString stringWithFormat: @"/tmp/wsbsd-wpa-%d-%d", getpid(), __sync_fetch_and_add(&gCounter, 1)]; strlcpy(l.sun_path, [_local fileSystemRepresentation], sizeof l.sun_path); unlink(l.sun_path);
		if (bind(_fd, (struct sockaddr *)&l, sizeof l) != 0) { close(_fd); return nil; }
		struct sockaddr_un r = { .sun_family = AF_UNIX }; strlcpy(r.sun_path, [path fileSystemRepresentation], sizeof r.sun_path); if (connect(_fd, (struct sockaddr *)&r, sizeof r) != 0) { close(_fd); unlink(l.sun_path); return nil; }
	}
	return self;
}
- (NSString *)request:(NSString *)cmd timeout:(double)t
{
	const char *c = [cmd UTF8String]; if (send(_fd, c, strlen(c), 0) < 0) return nil;
	struct pollfd p = { .fd = _fd, .events = POLLIN }; if (poll(&p, 1, (int)(t * 1000)) <= 0) return nil; char buf[65536]; ssize_t n = recv(_fd, buf, sizeof buf - 1, 0); if (n < 0) return nil; buf[n] = 0; return @(buf);
}
- (int)fd { return _fd; }
- (void)close { if (_fd >= 0) { close(_fd); _fd = -1; unlink([_local fileSystemRepresentation]); } }
@end

@implementation WSWiFiWpaBackend { NSString *_dir, *_ifconfig; NSMutableDictionary<NSString *, WSWpaCtrl *> *_ctrl; NSMutableDictionary *_events; NSLock *_lock; NSMutableDictionary *_waiters; }
@synthesize eventHandler;
- (instancetype)initWithControlDirectory:(NSString *)dir ifconfig:(NSString *)ifconfig
{
	if ((self = [super init])) {
		_dir = [dir copy]; _ifconfig = [ifconfig copy] ?: @"/sbin/ifconfig"; _ctrl = [NSMutableDictionary dictionary]; _lock = [NSLock new]; _waiters = [NSMutableDictionary dictionary];
		for (NSString *n in [self interfaceNames]) { WSWpaCtrl *c = [[WSWpaCtrl alloc] initWithPath: [_dir stringByAppendingPathComponent: n]]; if (!c) continue; _ctrl[n] = c; [self _monitor: n]; }
	}
	return self;
}
- (NSArray *)interfaceNames
{
	NSMutableArray *a = [NSMutableArray array]; DIR *d = opendir([_dir fileSystemRepresentation]); if (!d) return a; struct dirent *e; while ((e = readdir(d))) { if (e->d_name[0] == '.') continue; struct stat st; NSString *p = [_dir stringByAppendingPathComponent: @(e->d_name)]; if (stat([p fileSystemRepresentation], &st) == 0 && S_ISSOCK(st.st_mode)) [a addObject: @(e->d_name)]; } closedir(d);
	return [a sortedArrayUsingSelector: @selector(compare:)];
}
- (NSString *)_run:(NSArray *)args { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: _ifconfig]; [t setArguments: args]; NSPipe *p = [NSPipe pipe]; [t setStandardOutput: p]; [t setStandardError: [NSPipe pipe]]; @try { [t launch]; } @catch (NSException *e) { return nil; } NSData *d = [[p fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit]; return [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; }
static NSDictionary *KV(NSString *text) { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSString *l in [text componentsSeparatedByString: @"\n"]) { NSRange r = [l rangeOfString: @"="]; if (r.location != NSNotFound) d[[l substringToIndex: r.location]] = [l substringFromIndex: NSMaxRange(r)]; } return d; }

/* ---- events: a second socket attached to the supplicant ---- */
static void *RunBlock(void *arg) { void (^b)(void) = (__bridge_transfer void (^)(void))arg; b(); return NULL; }
- (void)_monitor:(NSString *)iface
{
	WSWpaCtrl *m = [[WSWpaCtrl alloc] initWithPath: [_dir stringByAppendingPathComponent: iface]]; if (!m || ![[m request: @"ATTACH" timeout: 2] hasPrefix: @"OK"]) return; int fd = [m fd]; __weak WSWiFiWpaBackend *me = self;
	pthread_t t; pthread_attr_t a; pthread_attr_init(&a); pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED); void (^loop)(void) = ^{
		for (;;) { struct pollfd p = { .fd = fd, .events = POLLIN }; int r = poll(&p, 1, 5000); WSWiFiWpaBackend *s = me; if (!s) break; if (r < 0) break;
			if (r == 0) { NSDictionary *st = [s stateForInterface: iface]; if ([st[WSWiFiStateLinkUp] boolValue]) [s _emit: @"linkQuality" iface: iface info: @{ @"rssi": st[WSWiFiStateRSSI] ?: @0, @"rate": st[WSWiFiStateTxRate] ?: @0 }]; continue; }
			char buf[4096]; ssize_t n = recv(fd, buf, sizeof buf - 1, 0); if (n <= 0) break; buf[n] = 0; [s _handleEvent: @(buf) interface: iface]; }
	};
	pthread_create(&t, &a, RunBlock, (__bridge_retained void *)[loop copy]);
}
- (void)_emit:(NSString *)ev iface:(NSString *)n info:(NSDictionary *)info { void (^h)(NSString *, NSString *, NSDictionary *) = self.eventHandler; if (h) h(ev, n, info); }
- (void)_handleEvent:(NSString *)line interface:(NSString *)iface
{
	NSRange r = [line rangeOfString: @">"]; NSString *m = r.location != NSNotFound && [line hasPrefix: @"<"] ? [line substringFromIndex: NSMaxRange(r)] : line;
		if ([m hasPrefix: @"CTRL-EVENT-CONNECTED"]) { [self _remember: iface outcome: @"connected"]; [self _emit: @"ssid" iface: iface info: nil]; [self _emit: @"bssid" iface: iface info: nil]; [self _emit: @"link" iface: iface info: nil]; }
	else if ([m hasPrefix: @"CTRL-EVENT-DISCONNECTED"]) { [self _remember: iface outcome: @"disconnected"]; [self _emit: @"ssid" iface: iface info: nil]; [self _emit: @"bssid" iface: iface info: nil]; [self _emit: @"link" iface: iface info: nil]; }
	else if ([m hasPrefix: @"CTRL-EVENT-SCAN-RESULTS"]) { [self _remember: iface outcome: @"scan"]; [self _emit: @"scanCache" iface: iface info: nil]; }
	else if ([m hasPrefix: @"CTRL-EVENT-REGDOM-CHANGE"]) [self _emit: @"countryCode" iface: iface info: nil];
	else if ([m hasPrefix: @"CTRL-EVENT-SSID-TEMP-DISABLED"] || [m hasPrefix: @"CTRL-EVENT-AUTH-REJECT"] || [m hasPrefix: @"CTRL-EVENT-ASSOC-REJECT"]) [self _remember: iface outcome: [m containsString: @"WRONG_KEY"] || [m containsString: @"4way"] ? @"wrongkey" : @"rejected"];
}
- (void)_remember:(NSString *)iface outcome:(NSString *)o { [_lock lock]; _waiters[[iface stringByAppendingString: @"#outcome"]] = o; _waiters[[iface stringByAppendingString: @"#stamp"]] = @([NSDate timeIntervalSinceReferenceDate]); [_lock unlock]; }
- (NSString *)_waitOutcome:(NSString *)iface among:(NSArray *)ok since:(double)since timeout:(double)t
{
	double end = [NSDate timeIntervalSinceReferenceDate] + t;
	while ([NSDate timeIntervalSinceReferenceDate] < end) { [_lock lock]; NSString *o = _waiters[[iface stringByAppendingString: @"#outcome"]]; double st = [_waiters[[iface stringByAppendingString: @"#stamp"]] doubleValue]; [_lock unlock]; if (o && st >= since && [ok containsObject: o]) return o; usleep(50000); }
	return nil;
}

/* ---- state ---- */
- (NSString *)_if:(NSString *)n { return [_ctrl[n] description] ? n : n; }
- (NSDictionary *)stateForInterface:(NSString *)name
{
	WSWpaCtrl *c = _ctrl[name]; if (!c) return nil; NSMutableDictionary *st = [NSMutableDictionary dictionary];
	NSString *cfg = [self _run: @[ name ]]; BOOL up = [cfg containsString: @"<UP"] || [cfg containsString: @",UP"]; st[WSWiFiStatePower] = @(up);
	NSDictionary *status = KV([c request: @"STATUS" timeout: 2] ?: @""); st[WSWiFiStateMAC] = status[@"address"] ?: @""; st[WSWiFiStateOpMode] = @1;
	NSRange cr = [cfg rangeOfString: @"country "]; if (cr.location != NSNotFound) { NSString *rest = [cfg substringFromIndex: NSMaxRange(cr)]; if ([rest length] >= 2) st[WSWiFiStateCountry] = [rest substringToIndex: 2]; } else st[WSWiFiStateCountry] = @"";
	BOOL linked = up && [status[@"wpa_state"] isEqual: @"COMPLETED"]; st[WSWiFiStateLinkUp] = @(linked);
	if (linked) {
		NSString *bssid = status[@"bssid"]; int freq = [status[@"freq"] intValue]; NSDictionary *sp = KV([c request: @"SIGNAL_POLL" timeout: 2] ?: @""); NSDictionary *bss = KV([c request: [@"BSS " stringByAppendingString: bssid ?: @""] timeout: 2] ?: @"");
		NSData *ie = nil; NSString *hex = bss[@"ie"]; if ([hex length]) { NSMutableData *d = [NSMutableData data]; for (NSUInteger i = 0; i + 1 < [hex length]; i += 2) { unsigned x; sscanf([[hex substringWithRange: NSMakeRange(i, 2)] UTF8String], "%2x", &x); unsigned char b = (unsigned char)x; [d appendBytes: &b length: 1]; } ie = d; }
		NSMutableDictionary *rec = [NSMutableDictionary dictionary]; if (ie) [rec addEntriesFromDictionary: [WSIEParser scanRecordKeysForIEData: ie]]; NSData *ssid = rec[@"SSID"]; if (!ssid && status[@"ssid"]) ssid = [status[@"ssid"] dataUsingEncoding: NSUTF8StringEncoding]; if (ssid) { rec[@"SSID"] = ssid; NSString *s = [WSIEParser SSIDStringForData: ssid]; if (s) rec[@"SSID_STR"] = s; }
		rec[@"BSSID"] = bssid; rec[@"CHANNEL"] = @(ChannelForFreq(freq)); rec[@"CHANNEL_FLAGS"] = @(FlagsForFreq(freq)); rec[@"RSSI"] = @([sp[@"RSSI"] intValue]); rec[@"NOISE"] = @([sp[@"NOISE"] intValue] ?: -92); rec[@"BEACON_INT"] = @([bss[@"beacon_int"] intValue] ?: 100); rec[@"AP_MODE"] = @2;
		st[WSWiFiStateScanRecord] = rec; st[WSWiFiStateSSID] = ssid; st[WSWiFiStateBSSID] = bssid; st[WSWiFiStateChannel] = rec[@"CHANNEL"]; st[WSWiFiStateChannelFlags] = rec[@"CHANNEL_FLAGS"]; st[WSWiFiStateRSSI] = rec[@"RSSI"]; st[WSWiFiStateNoise] = rec[@"NOISE"]; st[WSWiFiStateTxRate] = @([sp[@"LINKSPEED"] doubleValue]);
	}
	return st;
}
- (BOOL)setPower:(BOOL)on forInterface:(NSString *)name error:(NSError **)error
{
	if (!_ctrl[name]) { if (error) *error = Err(-3900, @"no such interface"); return NO; } NSString *r = [self _run: @[ name, on ? @"up" : @"down" ]]; (void)r; BOOL now = [[self stateForInterface: name][WSWiFiStatePower] boolValue];
	if (now != on) { if (error) *error = Err(-3906, @"ifconfig failed"); return NO; } [self _emit: @"power" iface: name info: nil]; return YES;
}
- (NSArray *)scanInterface:(NSString *)name ssid:(NSData *)ssid error:(NSError **)error
{
	WSWpaCtrl *c = _ctrl[name]; if (!c) { if (error) *error = Err(-3900, @"no such interface"); return nil; } if (![[self stateForInterface: name][WSWiFiStatePower] boolValue]) { if (error) *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: 6 userInfo: nil]; return nil; }
	double since = [NSDate timeIntervalSinceReferenceDate]; NSString *r = [c request: @"SCAN" timeout: 3]; if (!r || (![r hasPrefix: @"OK"] && ![r hasPrefix: @"FAIL-BUSY"])) { if (error) *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: 16 userInfo: nil]; return nil; }
	[self _waitOutcome: name among: @[ @"scan" ] since: since timeout: 10]; NSString *results = [c request: @"SCAN_RESULTS" timeout: 5] ?: @""; NSMutableArray *out = [NSMutableArray array]; NSArray *lines = [results componentsSeparatedByString: @"\n"];
	for (NSUInteger i = 1; i < [lines count]; i++) { NSArray *f = [lines[i] componentsSeparatedByString: @"\t"]; if ([f count] < 4) continue; NSString *bssid = f[0]; int freq = [f[1] intValue], level = [f[2] intValue]; NSString *flags = f[3];
		NSDictionary *bss = KV([c request: [@"BSS " stringByAppendingString: bssid] timeout: 2] ?: @""); NSString *hex = bss[@"ie"]; NSMutableData *ie = [NSMutableData data]; for (NSUInteger k = 0; k + 1 < [hex length]; k += 2) { unsigned x; sscanf([[hex substringWithRange: NSMakeRange(k, 2)] UTF8String], "%2x", &x); unsigned char b = (unsigned char)x; [ie appendBytes: &b length: 1]; }
		NSMutableDictionary *rec = [NSMutableDictionary dictionaryWithDictionary: [WSIEParser scanRecordKeysForIEData: ie]]; NSData *sd = rec[@"SSID"]; if (!sd && [f count] > 4) sd = [f[4] dataUsingEncoding: NSUTF8StringEncoding]; if (ssid && ![sd isEqual: ssid]) continue;
		if (sd) { rec[@"SSID"] = sd; NSString *s = [WSIEParser SSIDStringForData: sd]; if (s) rec[@"SSID_STR"] = s; } rec[@"BSSID"] = bssid; rec[@"CHANNEL"] = @(ChannelForFreq(freq)); rec[@"CHANNEL_FLAGS"] = @(FlagsForFreq(freq)); rec[@"RSSI"] = @(level); rec[@"NOISE"] = @-92; rec[@"BEACON_INT"] = @([bss[@"beacon_int"] intValue] ?: 100);
		rec[@"AP_MODE"] = [flags containsString: @"[IBSS]"] ? @1 : @2; if ([hex length]) rec[@"IE"] = ie; [out addObject: rec]; }
	return out;
}
static NSString *Quote(NSString *s) { return [[s stringByReplacingOccurrencesOfString: @"\\" withString: @"\\\\"] stringByReplacingOccurrencesOfString: @"\"" withString: @"\\\""]; }
static NSString *Hex(NSData *d) { NSMutableString *h = [NSMutableString string]; const unsigned char *b = [d bytes]; for (NSUInteger i = 0; i < [d length]; i++) [h appendFormat: @"%02x", b[i]]; return h; }
- (BOOL)associateInterface:(NSString *)name toRecord:(NSDictionary *)rec password:(NSString *)pw error:(NSError **)error
{
	WSWpaCtrl *c = _ctrl[name]; if (!c) { if (error) *error = Err(-3900, @"no such interface"); return NO; }
	NSDictionary *rsn = rec[@"RSN_IE"]; NSArray *akms = rsn[@"IE_KEY_RSN_AUTHSELS"]; BOOL sae = [akms containsObject: @8] || [akms containsObject: @9], psk = [akms containsObject: @2] || [akms containsObject: @4] || [akms containsObject: @6], owe = [akms containsObject: @18], ent = [akms containsObject: @1] || [akms containsObject: @5];
	BOOL wpa = rec[@"WPA_IE"] != nil, open = !rsn && !wpa;
	if (ent || [rec[@"WPA_IE"][@"IE_KEY_WPA_AUTHSELS"] containsObject: @1]) { if (error) *error = Err(-3903, @"enterprise networks need an EAP profile"); return NO; }
	if (!open && !owe && ![pw length]) { if (error) *error = Err(-3900, @"password required"); return NO; }
	[c request: @"REMOVE_NETWORK all" timeout: 2]; NSString *idr = [[c request: @"ADD_NETWORK" timeout: 2] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (![idr length]) { if (error) *error = Err(-3906, @"ADD_NETWORK failed"); return NO; }
	NSData *ssid = rec[@"SSID"]; NSMutableArray *cmds = [NSMutableArray array]; [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ ssid %@", idr, Hex(ssid)]]; if (rec[@"BSSID"] && [rec[@"BSSID"] length]) [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ bssid %@", idr, rec[@"BSSID"]]];
	if (open) [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ key_mgmt NONE", idr]];
	else if (owe) [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ key_mgmt OWE", idr]];
	else if (sae && !psk) { [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ key_mgmt SAE", idr]]; [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ sae_password \"%@\"", idr, Quote(pw)]]; [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ ieee80211w 2", idr]]; }
	else { [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ key_mgmt %@", idr, sae ? @"WPA-PSK SAE" : @"WPA-PSK"]]; [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ psk \"%@\"", idr, Quote(pw)]]; if (sae) [cmds addObject: [NSString stringWithFormat: @"SET_NETWORK %@ ieee80211w 1", idr]]; }
	for (NSString *cmd in cmds) { NSString *r = [c request: cmd timeout: 2]; if (![r hasPrefix: @"OK"]) { if (error) *error = Err(-3900, [NSString stringWithFormat: @"%@ -> %@", cmd, r]); return NO; } }
	double since = [NSDate timeIntervalSinceReferenceDate]; if (![[c request: [NSString stringWithFormat: @"SELECT_NETWORK %@", idr] timeout: 2] hasPrefix: @"OK"]) { if (error) *error = Err(-3906, @"SELECT_NETWORK failed"); return NO; }
	NSString *o = [self _waitOutcome: name among: @[ @"connected", @"wrongkey", @"rejected" ] since: since timeout: 25];
	if ([o isEqual: @"connected"]) return YES; if (error) *error = Err([o isEqual: @"wrongkey"] ? -3900 : o ? -3909 : -3905, o ?: @"timeout"); [c request: @"DISCONNECT" timeout: 2]; return NO;
}
- (void)disassociateInterface:(NSString *)name { [_ctrl[name] request: @"DISCONNECT" timeout: 2]; }
- (NSArray *)supportedChannelsForInterface:(NSString *)name
{
	NSString *t = [self _run: @[ name, @"list", @"chan" ]]; NSMutableArray *a = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
	for (NSString *l in [t componentsSeparatedByString: @"\n"]) { int ch = 0, f = 0; if (sscanf([l UTF8String], " Channel %d : %d", &ch, &f) == 2 && ch > 0 && ![seen containsObject: @(ch * 10000 + f)]) { [seen addObject: @(ch * 10000 + f)]; [a addObject: @{ @"CHANNEL": @(ch), @"CHANNEL_FLAGS": @(FlagsForFreq(f)) }]; } }
	return a;
}
@end

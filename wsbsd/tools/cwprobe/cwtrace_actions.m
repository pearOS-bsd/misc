/* cwtrace_actions (macOS only): the methods of CWInterface / CWWiFiClient that take arguments and are safe to run (scans, queries, event monitoring); see trace.sh */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
@interface CWInterface (P) - (NSSet *)cachedTrimmedScanResultsWithProperties:(NSArray *)p; @end
int main(void)
{
	@autoreleasepool { CWWiFiClient *c = [CWWiFiClient sharedWiFiClient]; CWInterface *i = [c interface]; NSError *e = nil;
		NSLog(@"MARK scanForNetworksWithName:nil"); (void)[i scanForNetworksWithName: nil error: &e];
		NSLog(@"MARK scanForNetworksWithName:x"); (void)[i scanForNetworksWithName: @"x" error: &e];
		NSLog(@"MARK scanForNetworksWithSSID:"); (void)[i scanForNetworksWithSSID: [@"x" dataUsingEncoding: NSUTF8StringEncoding] error: &e];
		NSLog(@"MARK scanForNetworksWithSSID:includeHidden:"); (void)[i scanForNetworksWithSSID: nil includeHidden: YES error: &e];
		NSLog(@"MARK cachedScanResults"); (void)[i cachedScanResults];
		NSLog(@"MARK startMonitoringEventWithType:link"); (void)[c startMonitoringEventWithType: CWEventTypeLinkDidChange error: &e];
		NSLog(@"MARK stopMonitoringEventWithType:link"); (void)[c stopMonitoringEventWithType: CWEventTypeLinkDidChange error: &e];
		NSLog(@"MARK startMonitoringEventWithType:ssid"); (void)[c startMonitoringEventWithType: CWEventTypeSSIDDidChange error: &e];
		NSLog(@"MARK stopMonitoringAllEvents"); (void)[c stopMonitoringAllEventsAndReturnError: &e];
		NSLog(@"MARK interfaceWithName:en0"); (void)[c interfaceWithName: @"en0"];
		NSLog(@"MARK configuration.networkProfiles"); (void)[[i configuration] networkProfiles];
		NSLog(@"MARK done"); }
	return 0;
}

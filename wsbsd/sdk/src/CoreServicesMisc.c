/* Launch Services, Spotlight and the Process Manager as far as a system without them can answer: nothing is known, the calls say so. */
#include <CoreServices/CoreServices.h>
CFArrayRef LSCopyApplicationURLsForURL(CFURLRef inURL, LSRolesMask inRoleMask) { (void)inURL; (void)inRoleMask; return CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks); }
CFURLRef LSCopyDefaultApplicationURLForURL(CFURLRef inURL, LSRolesMask inRoleMask, CFErrorRef *outError) { (void)inURL; (void)inRoleMask; if (outError) *outError = NULL; return NULL; }
MDItemRef MDItemCreateWithURL(CFAllocatorRef allocator, CFURLRef url) { (void)allocator; (void)url; return NULL; }
MDItemRef MDItemCreate(CFAllocatorRef allocator, CFStringRef path) { (void)allocator; (void)path; return NULL; }
CFTypeRef MDItemCopyAttribute(MDItemRef item, CFStringRef name) { (void)item; (void)name; return NULL; }
CFDictionaryRef MDItemCopyAttributes(MDItemRef item, CFArrayRef names) { (void)item; (void)names; return NULL; }
OSStatus GetProcessForPID(pid_t pid, ProcessSerialNumber *psn) { (void)pid; if (psn) psn->highLongOfPSN = psn->lowLongOfPSN = 0; return procNotFound; }
OSStatus CopyProcessName(const ProcessSerialNumber *psn, CFStringRef *name) { (void)psn; if (name) *name = NULL; return paramErr; }

/* AudioToolbox: the alert sound is the bell of the terminal this process was started from (no sound server) */
#include <unistd.h>
void AudioServicesPlayAlertSound(uint32_t id) { (void)id; if (write(2, "\a", 1) < 0) { } }
void AudioServicesPlaySystemSound(uint32_t id) { AudioServicesPlayAlertSound(id); }

/* Gestalt: system version as macOS 10.16, the memory and processor count of this machine */
#include <CoreServices/Gestalt.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#undef sysctl
int16_t Gestalt(uint32_t selector, int32_t *response)
{
	if (!response) return -50;
	switch (selector) {
	case gestaltSystemVersion: *response = 0x1160; return 0;
	case gestaltSystemVersionMajor: *response = 10; return 0;
	case gestaltSystemVersionMinor: *response = 16; return 0;
	case gestaltSystemVersionBugFix: *response = 0; return 0;
	case gestaltPhysicalRAMSize: { unsigned long mem = 0; size_t n = sizeof mem; if (sysctlbyname("hw.physmem", &mem, &n, NULL, 0) == 0) *response = (int32_t)(mem >> 20); else *response = 0; return 0; }
	case gestaltProcessorCount: { int cpus = 1; size_t n = sizeof cpus; sysctlbyname("hw.ncpu", &cpus, &n, NULL, 0); *response = cpus; return 0; }
	}
	*response = 0; return -5551;                                                    /* gestaltUndefSelectorErr */
}

/* confstr with Darwin's per-user directories, exchangedata, the Resource Manager and Launch Services info (no forks, no type codes) */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <CoreServices/ResourceManager.h>
#include <CoreServices/LaunchServices.h>
#undef confstr
size_t wsbsd_confstr(int name, char *buf, size_t len)
{
	if (name < 65536 || name > 65538) return confstr(name, buf, len);
	char dir[128]; const char *sub = name == 65536 ? "0" : name == 65537 ? "T" : "C";
	snprintf(dir, sizeof dir, "/var/tmp/wsbsd-%u", (unsigned)getuid()); mkdir(dir, 0700);
	char full[160]; snprintf(full, sizeof full, "%s/%s", dir, sub); mkdir(full, 0700);
	strlcat(full, "/", sizeof full); size_t n = strlen(full) + 1; if (buf && len) strlcpy(buf, full, len);   /* the length wanted, NUL included, as confstr answers */
	return n;
}
int exchangedata(const char *path1, const char *path2, unsigned int options)                 /* swaps the two files' contents: three renames (the names swap, not the inodes) */
{
	(void)options; char tmp[PATH_MAX + 16];
	if (snprintf(tmp, sizeof tmp, "%s.wsbsd-swap", path1) >= (int)sizeof tmp) { errno = ENAMETOOLONG; return -1; }
	if (rename(path1, tmp) != 0) return -1;
	if (rename(path2, path1) != 0) { int e = errno; rename(tmp, path1); errno = e; return -1; }
	if (rename(tmp, path2) != 0) return -1;
	return 0;
}
ResFileRefNum FSOpenResFile(const FSRef *ref, int8_t permission) { (void)ref; (void)permission; return 0; }
void CloseResFile(ResFileRefNum refNum) { (void)refNum; }
Handle Get1Resource(ResType theType, ResID theID) { (void)theType; (void)theID; return NULL; }
void HLock(Handle h) { (void)h; }
void HUnlock(Handle h) { (void)h; }
long GetHandleSize(Handle h) { (void)h; return 0; }
void ReleaseResource(Handle h) { (void)h; }
int32_t LSCopyItemInfoForURL(CFURLRef inURL, LSRequestedInfo inWhichInfo, LSItemInfoRecord *outItemInfo)
{
	(void)inURL; (void)inWhichInfo; if (outItemInfo) { outItemInfo->flags = 0; outItemInfo->filetype = 0; outItemInfo->creator = 0; outItemInfo->extension = NULL; } return 0;
}


/* gethostuuid: kern.hostuuid is the UUID string of the machine (SMBIOS); all zeros when the kernel has none */
#include <time.h>
int gethostuuid(unsigned char uuid[16], const struct timespec *wait)
{
	(void)wait; char buf[64] = ""; size_t n = sizeof buf; memset(uuid, 0, 16);
	if (sysctlbyname("kern.hostuuid", buf, &n, NULL, 0) != 0) return -1;
	unsigned int b[16]; if (sscanf(buf, "%2x%2x%2x%2x-%2x%2x-%2x%2x-%2x%2x-%2x%2x%2x%2x%2x%2x", &b[0], &b[1], &b[2], &b[3], &b[4], &b[5], &b[6], &b[7], &b[8], &b[9], &b[10], &b[11], &b[12], &b[13], &b[14], &b[15]) != 16) return -1;
	for (int i = 0; i < 16; i++) uuid[i] = (unsigned char)b[i]; return 0;
}

/* basename_r / dirname_r: the POSIX results copied into the caller's buffer (NULL with errno on failure) */
#include <libgen.h>
char *basename_r(const char *path, char *bname)
{
	char tmp[1024]; if (!path) path = ""; strncpy(tmp, path, sizeof tmp - 1); tmp[sizeof tmp - 1] = 0;
	char *r = basename(tmp); if (!r) return NULL; strcpy(bname, r); return bname;
}
char *dirname_r(const char *path, char *dname)
{
	char tmp[1024]; if (!path) path = ""; strncpy(tmp, path, sizeof tmp - 1); tmp[sizeof tmp - 1] = 0;
	char *r = dirname(tmp); if (!r) return NULL; strcpy(dname, r); return dname;
}

/* system sounds: ids for files are handed out and remembered; playing any of them is the terminal bell */
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <AudioToolbox/AudioToolbox.h>
OSStatus AudioServicesCreateSystemSoundID(CFURLRef url, SystemSoundID *out) { static SystemSoundID next = 0x2000; (void)url; if (!out) return -50; *out = next++; return 0; }
OSStatus AudioServicesDisposeSystemSoundID(SystemSoundID id) { (void)id; return 0; }

/* symbolic hot keys: no-ops */
void *PushSymbolicHotKeyMode(uint32_t options) { (void)options; return (void *)1; }
void PopSymbolicHotKeyMode(void *token) { (void)token; }

/* reachability: a host is reachable when some non-loopback interface is up and has an address (the name is not resolved) */
struct __SCNetworkReachability { int dummy; };
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName(CFAllocatorRef a, const char *name) { (void)a; (void)name; return calloc(1, sizeof(struct __SCNetworkReachability)); }
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress(CFAllocatorRef a, const void *addr) { (void)a; (void)addr; return calloc(1, sizeof(struct __SCNetworkReachability)); }
Boolean SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef t, SCNetworkReachabilityFlags *flags)
{
	(void)t; struct ifaddrs *ifs, *i; int up = 0; if (!flags) return false; *flags = 0; if (getifaddrs(&ifs)) return false;
	for (i = ifs; i; i = i->ifa_next) if (i->ifa_addr && (i->ifa_addr->sa_family == AF_INET || i->ifa_addr->sa_family == AF_INET6) && (i->ifa_flags & IFF_UP) && !(i->ifa_flags & IFF_LOOPBACK)) up = 1;
	freeifaddrs(ifs); if (up) *flags = kSCNetworkReachabilityFlagsReachable; return true;
}

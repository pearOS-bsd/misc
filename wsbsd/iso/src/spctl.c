/* /usr/sbin/spctl: the Gatekeeper command, for the part that exists here: the verdict on a file or application and the on/off switch.
 *   spctl --assess [--type execute|open|install] [-v[v]] path ...   exit 0 accepted, 3 rejected; a quarantined item the user has not approved is rejected
 *   spctl --status | --global-enable | --global-disable | --master-enable | --master-disable
 * The switch is the file /private/var/db/.SystemPolicyDisabled (absent: assessments enabled); the quarantine check of the Launch Services calls honours it as well. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>
#define SWITCH "/private/var/db/.SystemPolicyDisabled"
static int enabled(void) { return access(SWITCH, F_OK) != 0; }
int main(int argc, char **argv)
{
	int assess = 0, verbose = 0, rc = 0, i;
	for (i = 1; i < argc; i++) {
		const char *a = argv[i];
		if (!strcmp(a, "--status") || !strcmp(a, "--global-status")) { puts(enabled() ? "assessments enabled" : "assessments disabled"); return enabled() ? 0 : 1; }
		if (!strcmp(a, "--global-disable") || !strcmp(a, "--master-disable")) { mkdir("/private/var/db", 0755); FILE *f = fopen(SWITCH, "w"); if (!f) { perror(SWITCH); return 1; } fclose(f); return 0; }
		if (!strcmp(a, "--global-enable") || !strcmp(a, "--master-enable")) { unlink(SWITCH); return 0; }
		if (!strcmp(a, "--assess") || !strcmp(a, "-a")) assess = 1;
		else if (!strcmp(a, "-v") || !strcmp(a, "-vv") || !strcmp(a, "--verbose")) verbose = 1;
		else if (!strcmp(a, "--type") || !strcmp(a, "-t")) i++;
		else if (a[0] != '-') break;
	}
	if (!assess || i >= argc) { fprintf(stderr, "usage: spctl --assess [--type execute|open|install] [-v] path ...\n       spctl --status | --global-enable | --global-disable\n"); return 2; }
	for (; i < argc; i++) {
		char q[512]; ssize_t n = getxattr(argv[i], "com.apple.quarantine", q, sizeof q - 1, 0, 0); unsigned flags = 0; int ok = 1;
		if (access(argv[i], F_OK)) { fprintf(stderr, "%s: No such file or directory\n", argv[i]); rc = 1; continue; }
		if (n > 0) { q[n] = 0; sscanf(q, "%x", &flags); if (!(flags & 0x40) && enabled()) ok = 0; }
		if (verbose || !ok) printf("%s: %s\n", argv[i], ok ? "accepted" : "rejected");
		if (verbose) printf("source=%s\n", ok ? (n > 0 ? "Approved by the user" : "Local item (not quarantined)") : "no usable signature (quarantined, not approved)");
		if (!ok) rc = 3;
	}
	return rc;
}

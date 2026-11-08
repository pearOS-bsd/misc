/* evdevprobe: every /dev/input/event* with its name, ids and capabilities (is it a multi-touch pad, which finger counts it reports, which keys), for the hardware report */
#include <dev/evdev/input.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#define BIT(a, n) ((a)[(n) / 8] >> ((n) % 8) & 1)
int main(void)
{
	char path[64];
	for (int i = 0; i < 32; i++) {
		snprintf(path, sizeof path, "/dev/input/event%d", i); int fd = open(path, O_RDONLY | O_NONBLOCK); if (fd < 0) continue;
		char name[128] = "?"; struct input_id id = { 0 }; ioctl(fd, EVIOCGNAME(sizeof name), name); ioctl(fd, EVIOCGID, &id);
		unsigned char ev[(EV_MAX + 8) / 8] = { 0 }, key[(KEY_MAX + 8) / 8] = { 0 }, abs[(ABS_MAX + 8) / 8] = { 0 };
		ioctl(fd, EVIOCGBIT(0, sizeof ev), ev); ioctl(fd, EVIOCGBIT(EV_KEY, sizeof key), key); ioctl(fd, EVIOCGBIT(EV_ABS, sizeof abs), abs);
		printf("%s \"%s\" bus %04x vendor %04x product %04x  types:%s%s%s%s%s\n", path, name, id.bustype, id.vendor, id.product, BIT(ev, EV_KEY) ? " KEY" : "", BIT(ev, EV_REL) ? " REL" : "", BIT(ev, EV_ABS) ? " ABS" : "", BIT(ev, EV_LED) ? " LED" : "", BIT(ev, EV_MSC) ? " MSC" : "");
		if (BIT(ev, EV_ABS)) {
			static const struct { int c; const char *n; } ax[] = { { ABS_X, "X" }, { ABS_Y, "Y" }, { ABS_MT_SLOT, "MT_SLOT" }, { ABS_MT_POSITION_X, "MT_X" }, { ABS_MT_POSITION_Y, "MT_Y" }, { ABS_MT_TRACKING_ID, "MT_ID" }, { ABS_MT_PRESSURE, "MT_PRESSURE" }, { ABS_PRESSURE, "PRESSURE" } };
			for (unsigned k = 0; k < sizeof ax / sizeof *ax; k++) if (BIT(abs, ax[k].c)) { struct input_absinfo a; if (ioctl(fd, EVIOCGABS(ax[k].c), &a) == 0) printf("    ABS_%s min %d max %d res %d\n", ax[k].n, a.minimum, a.maximum, a.resolution); }
		}
		if (BIT(ev, EV_KEY)) {
			static const struct { int c; const char *n; } kk[] = { { BTN_LEFT, "BTN_LEFT" }, { BTN_TOUCH, "BTN_TOUCH" }, { BTN_TOOL_FINGER, "TOOL_FINGER" }, { BTN_TOOL_DOUBLETAP, "TOOL_DOUBLETAP" }, { BTN_TOOL_TRIPLETAP, "TOOL_TRIPLETAP" }, { BTN_TOOL_QUADTAP, "TOOL_QUADTAP" }, { BTN_TOOL_QUINTTAP, "TOOL_QUINTTAP" }, { KEY_KBDILLUMUP, "KBDILLUMUP" }, { KEY_KBDILLUMDOWN, "KBDILLUMDOWN" }, { KEY_KBDILLUMTOGGLE, "KBDILLUMTOGGLE" }, { KEY_BRIGHTNESSUP, "BRIGHTNESSUP" }, { KEY_F1, "F1" } };
			printf("   "); for (unsigned k = 0; k < sizeof kk / sizeof *kk; k++) if (BIT(key, kk[k].c)) printf(" %s", kk[k].n); printf("\n");
		}
		close(fd);
	}
	return 0;
}

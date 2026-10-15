/* Console (VT) switching for the KMS backend on FreeBSD vt(4). While wsd owns the display it puts its VT into graphics mode and turns the console keyboard off, and it asks the kernel to
 * hand over SIGUSR1 when the user switches away (release) and SIGUSR2 when the VT comes back (acquire). While another VT is active wsd drops DRM master and discards raw input, so keystrokes
 * typed on the other console never reach the window server (or its clients). */
#ifdef WS_KMS
#include "wsd_priv.h"
#include <fcntl.h>
#include <string.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/ioctl.h>
#ifdef __FreeBSD__
#include <sys/consio.h>
#include <sys/kbio.h>
#endif

static int vtfd = -1, old_kbmode = -1;

/* 0: VT mode is set up; -1: this process is not on a vt(4) console (or the system has none): run without switching support */
int wsd_vt_setup(void)
{
#ifdef __FreeBSD__
	vtfd = open("/dev/tty", O_RDWR | O_CLOEXEC);
	if (vtfd < 0) return -1;
	int active = 0;
	if (ioctl(vtfd, VT_GETACTIVE, &active) < 0) { close(vtfd); vtfd = -1; return -1; }
	struct vt_mode m; memset(&m, 0, sizeof m);
	m.mode = VT_PROCESS; m.relsig = SIGUSR1; m.acqsig = SIGUSR2; m.frsig = SIGUSR2;
	if (ioctl(vtfd, VT_SETMODE, &m) < 0) { close(vtfd); vtfd = -1; return -1; }
	if (ioctl(vtfd, KDGKBMODE, &old_kbmode) < 0) old_kbmode = -1;
	ioctl(vtfd, KDSKBMODE, K_OFF);                       /* the console keyboard driver must not echo keystrokes into the VT */
	ioctl(vtfd, KDSETMODE, KD_GRAPHICS);
	return 0;
#else
	return -1;
#endif
}

void wsd_vt_release_ack(void) { if (vtfd >= 0) { 
#ifdef __FreeBSD__
	ioctl(vtfd, VT_RELDISP, 1);
#endif
} }
void wsd_vt_acquire_ack(void) { if (vtfd >= 0) {
#ifdef __FreeBSD__
	ioctl(vtfd, VT_RELDISP, VT_ACKACQ);
#endif
} }

void wsd_vt_restore(void)
{
#ifdef __FreeBSD__
	if (vtfd < 0) return;
	ioctl(vtfd, KDSETMODE, KD_TEXT);
	if (old_kbmode >= 0) ioctl(vtfd, KDSKBMODE, old_kbmode);
	struct vt_mode m; memset(&m, 0, sizeof m); m.mode = VT_AUTO;
	ioctl(vtfd, VT_SETMODE, &m);
	close(vtfd); vtfd = -1;
#endif
}
#endif

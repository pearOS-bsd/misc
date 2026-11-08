/*
 * clevo_dchu: keyboard backlight of Clevo / Tongfang laptops that expose the "DCHU" ACPI device (CLV0001), such as the NS50_70MU.
 * The BIOS offers the controls as the _DSM method of \_SB.DCHU (UUID 93f224e4-fbdc-4bbf-add6-db71bdc0afad): the function number is the command,
 * the argument a package holding a 4-byte buffer. Found in the DSDT of the NS50_70MU (BIOS 1.07.09LWL) and tried on it from Linux with acpi_call:
 *   function 0x67, argument 0xF4000000 | level      keyboard backlight brightness 0 ... 255 (EC command 0xCA, data 6)
 *   function 0x67, argument 0xF0|zone<<24 ... : 0xF0RRGGBB zone 0 (left), 0xF1RRGGBB zone 1 (middle), 0xF2RRGGBB zone 2 (right): colours of the three zones
 * Writable by any user (CTLFLAG_ANYBODY: the Control Center slider runs as the signed-in user). Exposes dev.clevo_dchu.0.kb_brightness (0 ... 255), kb_state (0 off, 1 on) and kb_color (0xRRGGBB for all three zones) for the Control Center and the rc script.
 * Build: make -C kmod/clevo_dchu SYSDIR=/usr/src/sys   load: kldload ./clevo_dchu.ko
 */
#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/bus.h>
#include <sys/sysctl.h>
#include <contrib/dev/acpica/include/acpi.h>
#include <contrib/dev/acpica/include/accommon.h>
#include <dev/acpica/acpivar.h>

#define DCHU_FN_KBD	0x67
#define DCHU_KB_LEVEL	0xF4000000u
#define DCHU_KB_ZONE(z)	(0xF0000000u | ((uint32_t)(z) << 24))

struct dchu_softc { device_t dev; ACPI_HANDLE handle; int brightness, state; uint32_t color; };

static char *dchu_ids[] = { "CLV0001", NULL };

static int
dchu_call(struct dchu_softc *sc, uint32_t fn, uint32_t arg)
{
	static UINT8 uuid[16] = { 0xe4, 0x24, 0xf2, 0x93, 0xdc, 0xfb, 0xbf, 0x4b, 0xad, 0xd6, 0xdb, 0x71, 0xbd, 0xc0, 0xaf, 0xad };
	UINT8 abuf[4] = { arg & 0xff, (arg >> 8) & 0xff, (arg >> 16) & 0xff, (arg >> 24) & 0xff };
	ACPI_OBJECT inner, a[4]; ACPI_OBJECT_LIST list; ACPI_BUFFER ret = { ACPI_ALLOCATE_BUFFER, NULL }; ACPI_STATUS st;
	inner.Type = ACPI_TYPE_BUFFER; inner.Buffer.Length = sizeof abuf; inner.Buffer.Pointer = abuf;
	a[0].Type = ACPI_TYPE_BUFFER; a[0].Buffer.Length = sizeof uuid; a[0].Buffer.Pointer = uuid;
	a[1].Type = ACPI_TYPE_INTEGER; a[1].Integer.Value = 0;
	a[2].Type = ACPI_TYPE_INTEGER; a[2].Integer.Value = fn;
	a[3].Type = ACPI_TYPE_PACKAGE; a[3].Package.Count = 1; a[3].Package.Elements = &inner;
	list.Count = 4; list.Pointer = a;
	st = AcpiEvaluateObject(sc->handle, "_DSM", &list, &ret);
	if (ret.Pointer != NULL) AcpiOsFree(ret.Pointer);
	return (ACPI_FAILURE(st) ? ENXIO : 0);
}
static int
dchu_apply(struct dchu_softc *sc)
{
	uint32_t level = sc->state ? (uint32_t)sc->brightness : 0;
	return (dchu_call(sc, DCHU_FN_KBD, DCHU_KB_LEVEL | (level & 0xff)));
}
static int
dchu_apply_color(struct dchu_softc *sc)
{
	int z, err = 0;
	for (z = 0; z < 3; z++) err |= dchu_call(sc, DCHU_FN_KBD, DCHU_KB_ZONE(z) | (sc->color & 0xffffff));
	return (err);
}
static int
sysctl_brightness(SYSCTL_HANDLER_ARGS)
{
	struct dchu_softc *sc = arg1; int v = sc->brightness, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || req->newptr == NULL) return (err);
	if (v < 0) v = 0; if (v > 255) v = 255;
	sc->brightness = v; sc->state = v > 0; return (dchu_apply(sc));
}
static int
sysctl_state(SYSCTL_HANDLER_ARGS)
{
	struct dchu_softc *sc = arg1; int v = sc->state, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || req->newptr == NULL) return (err);
	sc->state = v != 0; if (sc->state && sc->brightness == 0) sc->brightness = 128; return (dchu_apply(sc));
}
static int
sysctl_color(SYSCTL_HANDLER_ARGS)
{
	struct dchu_softc *sc = arg1; unsigned v = sc->color, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || req->newptr == NULL) return (err);
	sc->color = v & 0xffffff; return (dchu_apply_color(sc));
}
static int
dchu_probe(device_t dev)
{
	int rv;
	if (acpi_disabled("clevo_dchu")) return (ENXIO);
	rv = ACPI_ID_PROBE(device_get_parent(dev), dev, dchu_ids, NULL);
	if (rv > 0) return (rv);
	device_set_desc(dev, "Clevo / Tongfang keyboard backlight (DCHU)");
	return (rv);
}
static int
dchu_attach(device_t dev)
{
	struct dchu_softc *sc = device_get_softc(dev);
	sc->dev = dev; sc->handle = acpi_get_handle(dev); sc->brightness = 128; sc->state = 1; sc->color = 0xffffff;
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev), SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "kb_brightness", CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_ANYBODY | CTLFLAG_MPSAFE, sc, 0, sysctl_brightness, "I", "keyboard backlight brightness, 0 ... 255");
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev), SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "kb_state", CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_ANYBODY | CTLFLAG_MPSAFE, sc, 0, sysctl_state, "I", "keyboard backlight on / off");
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev), SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "kb_color", CTLTYPE_UINT | CTLFLAG_RW | CTLFLAG_ANYBODY | CTLFLAG_MPSAFE, sc, 0, sysctl_color, "IU", "colour of the three zones, 0xRRGGBB");
	dchu_apply_color(sc); dchu_apply(sc);
	return (0);
}
static device_method_t dchu_methods[] = { DEVMETHOD(device_probe, dchu_probe), DEVMETHOD(device_attach, dchu_attach), DEVMETHOD_END };
static driver_t dchu_driver = { "clevo_dchu", dchu_methods, sizeof(struct dchu_softc) };
DRIVER_MODULE(clevo_dchu, acpi, dchu_driver, 0, 0);
MODULE_DEPEND(clevo_dchu, acpi, 1, 1, 1);

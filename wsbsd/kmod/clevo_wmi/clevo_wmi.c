/*
 * clevo_wmi: keyboard backlight of Clevo / Tongfang laptops (NS50_70MU and its relatives) on FreeBSD, through the ACPI WMI interface the BIOS exposes for them (the one the Linux
 * drivers clevo-wmi and tuxedo-keyboard use: the method GUID ABBC0F6F-8EA1-11D1-00A0-C90629100000, the command number is the method id, the argument a 32-bit word).
 *
 * Exposes  dev.clevo_wmi.0.kb_brightness (0 ... 255, read / write)  and  dev.clevo_wmi.0.kb_state (0 off, 1 on), which the Control Center's Keyboard slider and the
 * brightness keys of the window server write.  Event keys (Fn + the backlight keys) arrive as WMI events on the GUID ABBC0F6B-...: the driver turns them into steps of 32.
 *
 * STATUS: written from the published behaviour of the Linux drivers; NOT run on the laptop (the author's machine is not at hand while this is written). The command numbers
 * (0x67 set the white backlight, 0xF4 + level as the argument; 0x46 read the event code) are the points to check first on a real NS50_70MU with a DSDT dump (acpidump -dt).
 * Build: make -C kmod/clevo_wmi  (needs /usr/src/sys), load with  kldload ./clevo_wmi.ko  (requires acpi_wmi).
 */
#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/module.h>
#include <sys/bus.h>
#include <sys/sysctl.h>
#include <sys/systm.h>
#include <contrib/dev/acpica/include/acpi.h>
#include <dev/acpica/acpivar.h>
#include "acpi_wmi_if.h"

#define CLEVO_METHOD_GUID	"ABBC0F6F-8EA1-11D1-00A0-C90629100000"
#define CLEVO_EVENT_GUID	"ABBC0F6B-8EA1-11D1-00A0-C90629100000"
#define CLEVO_CMD_SET_KB	0x67
#define CLEVO_ARG_WHITE		0xF4000000u

struct clevo_softc {
	device_t	dev, wmi;
	int		brightness, state;
};

static int
clevo_call(struct clevo_softc *sc, uint32_t method, uint32_t arg)
{
	ACPI_BUFFER in, out; ACPI_OBJECT obj;
	obj.Type = ACPI_TYPE_INTEGER; obj.Integer.Value = arg;
	in.Length = sizeof(obj); in.Pointer = &obj;
	out.Length = ACPI_ALLOCATE_BUFFER; out.Pointer = NULL;
	if (ACPI_WMI_EVALUATE_CALL(sc->wmi, CLEVO_METHOD_GUID, 0, method, &in, &out) != 0) return (ENXIO);
	if (out.Pointer != NULL) AcpiOsFree(out.Pointer);
	return (0);
}
static int
clevo_apply(struct clevo_softc *sc)
{
	uint32_t level = sc->state ? (uint32_t)sc->brightness : 0;
	return (clevo_call(sc, CLEVO_CMD_SET_KB, CLEVO_ARG_WHITE | (level & 0xff)));
}
static int
sysctl_brightness(SYSCTL_HANDLER_ARGS)
{
	struct clevo_softc *sc = arg1; int v = sc->brightness, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || req->newptr == NULL) return (err);
	if (v < 0) v = 0; if (v > 255) v = 255;
	sc->brightness = v; sc->state = v > 0; return (clevo_apply(sc));
}
static int
sysctl_state(SYSCTL_HANDLER_ARGS)
{
	struct clevo_softc *sc = arg1; int v = sc->state, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || req->newptr == NULL) return (err);
	sc->state = v != 0; if (sc->state && sc->brightness == 0) sc->brightness = 128; return (clevo_apply(sc));
}
static void
clevo_event(ACPI_HANDLE h, UINT32 notify, void *ctx)
{
	struct clevo_softc *sc = ctx; (void)h; (void)notify;
	/* the event code names the key; the backlight keys step the level */
	ACPI_BUFFER out = { ACPI_ALLOCATE_BUFFER, NULL };
	if (ACPI_WMI_GET_EVENT_DATA(sc->wmi, notify, &out) != 0 || out.Pointer == NULL) return;
	ACPI_OBJECT *o = out.Pointer; if (o->Type == ACPI_TYPE_INTEGER) {
		switch (o->Integer.Value) {
		case 0x81: sc->brightness = (sc->brightness + 32 > 255) ? 255 : sc->brightness + 32; sc->state = 1; clevo_apply(sc); break;
		case 0x82: sc->brightness = (sc->brightness < 32) ? 0 : sc->brightness - 32; sc->state = sc->brightness > 0; clevo_apply(sc); break;
		case 0x9f: sc->state = !sc->state; if (sc->state && !sc->brightness) sc->brightness = 128; clevo_apply(sc); break;
		}
	}
	AcpiOsFree(out.Pointer);
}
static int
clevo_probe(device_t dev)
{
	device_t wmi = device_get_parent(dev); (void)wmi;
	if (!ACPI_WMI_PROVIDES_GUID_STRING(device_get_parent(dev), CLEVO_METHOD_GUID)) return (ENXIO);
	device_set_desc(dev, "Clevo / Tongfang keyboard backlight (WMI)");
	return (BUS_PROBE_DEFAULT);
}
static int
clevo_attach(device_t dev)
{
	struct clevo_softc *sc = device_get_softc(dev);
	sc->dev = dev; sc->wmi = device_get_parent(dev); sc->brightness = 128; sc->state = 1;
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev), SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "kb_brightness", CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_MPSAFE, sc, 0, sysctl_brightness, "I", "keyboard backlight level 0 ... 255");
	SYSCTL_ADD_PROC(device_get_sysctl_ctx(dev), SYSCTL_CHILDREN(device_get_sysctl_tree(dev)), OID_AUTO, "kb_state", CTLTYPE_INT | CTLFLAG_RW | CTLFLAG_MPSAFE, sc, 0, sysctl_state, "I", "keyboard backlight on / off");
	ACPI_WMI_INSTALL_EVENT_HANDLER(sc->wmi, CLEVO_EVENT_GUID, clevo_event, sc);
	clevo_apply(sc);
	return (0);
}
static int
clevo_detach(device_t dev)
{
	struct clevo_softc *sc = device_get_softc(dev);
	ACPI_WMI_REMOVE_EVENT_HANDLER(sc->wmi, CLEVO_EVENT_GUID);
	return (0);
}
static device_method_t clevo_methods[] = {
	DEVMETHOD(device_probe, clevo_probe), DEVMETHOD(device_attach, clevo_attach), DEVMETHOD(device_detach, clevo_detach), DEVMETHOD_END
};
static driver_t clevo_driver = { "clevo_wmi", clevo_methods, sizeof(struct clevo_softc) };
DRIVER_MODULE(clevo_wmi, acpi_wmi, clevo_driver, 0, 0);
MODULE_DEPEND(clevo_wmi, acpi_wmi, 1, 1, 1);
MODULE_DEPEND(clevo_wmi, acpi, 1, 1, 1);

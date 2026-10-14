/* Connection / session / process level routines: version, session ports, client dictionaries, debug options, appearance. */
#include "wsd_priv.h"
#include <string.h>

int sls_golden_reply(conn *c, const mach_msg_header_t *h);

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_size == sizeof *h && len == sizeof *h) return sls_golden_reply(c, h);
	return -2;
}
void sls_session_owner_cleanup(uint32_t owner) { (void)owner; }

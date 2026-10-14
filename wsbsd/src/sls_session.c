/* Connection / session / process level routines: version, session ports, client dictionaries, debug options, appearance. */
#include "wsd_priv.h"
#include <string.h>

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	(void)c; (void)buf; (void)len;
	return -2;
}
void sls_session_owner_cleanup(uint32_t owner) { (void)owner; }

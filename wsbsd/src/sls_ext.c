/* Chains the protocol families implemented outside wsd.c. */
#include "wsd_priv.h"

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_session_owner_cleanup(uint32_t owner);

int sls_ext_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	int rc = sls_session_dispatch(c, buf, len);
	if (rc != -2) return rc;
	return -2;
}

void sls_ext_owner_cleanup(uint32_t owner) { sls_session_owner_cleanup(owner); }

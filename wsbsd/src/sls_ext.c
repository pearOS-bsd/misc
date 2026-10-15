/* Chains the protocol families implemented outside wsd.c. */
#include "wsd_priv.h"

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_session_owner_cleanup(uint32_t owner);
int sls_window_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_window_owner_cleanup(uint32_t owner);
int sls_transaction_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_display_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_harvest_reply(conn *c, const uint8_t *buf, size_t len);

int sls_ext_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	int rc = sls_session_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_display_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_transaction_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_window_dispatch(c, buf, len);
	if (rc != -2) return rc;
	return sls_harvest_reply(c, buf, len);           /* last: recorded behaviour of the real server for routines without a dedicated handler */
}

void sls_ext_owner_cleanup(uint32_t owner) { sls_session_owner_cleanup(owner); sls_window_owner_cleanup(owner); }

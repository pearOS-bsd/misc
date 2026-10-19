/* Chains the protocol families implemented outside wsd.c. */
#include "wsd_priv.h"

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_session_owner_cleanup(uint32_t owner);
int sls_window_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_tap_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_tap_owner_cleanup(uint32_t owner);
void sls_window_owner_cleanup(uint32_t owner);
int sls_transaction_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_display_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_sessctl_dispatch(conn *c, const uint8_t *buf, size_t len);
int sls_space_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_space_owner_cleanup(uint32_t owner);
int sls_hotkey_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_hotkey_owner_cleanup(uint32_t owner);
int sls_harvest_reply(conn *c, const uint8_t *buf, size_t len);
int sls_generic_reply(conn *c, const uint8_t *buf, size_t len);

int sls_ext_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	int rc = sls_hotkey_dispatch(c, buf, len);         /* first: header-only requests (GetGlobalHotKeyOperatingMode) would otherwise get the recorded reply */
	if (rc != -2) return rc;
	rc = sls_tap_dispatch(c, buf, len);               /* before the session family, whose recorded replies for header-only requests are the connection port's -303 */
	if (rc != -2) return rc;
	rc = sls_space_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_session_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_sessctl_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_display_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_transaction_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_window_dispatch(c, buf, len);
	if (rc != -2) return rc;
	rc = sls_harvest_reply(c, buf, len);             /* recorded behaviour of the real server for routines without a dedicated handler */
	if (rc != -2) return rc;
	return sls_generic_reply(c, buf, len);           /* last: wire-correct acceptors generated from the decompiled routines (success, right sizes) */
}

void sls_ext_owner_cleanup(uint32_t owner) { sls_session_owner_cleanup(owner); sls_window_owner_cleanup(owner); sls_hotkey_owner_cleanup(owner); sls_space_owner_cleanup(owner); sls_tap_owner_cleanup(owner); }

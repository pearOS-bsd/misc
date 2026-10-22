#!/usr/bin/env python3
"""gen_records.py N SEED > records.plist: random scan records (the dictionaries the Wi-Fi driver returns, with the keys of Apple80211) for the differential test of CWNetwork."""
import plistlib, random, sys
n = int(sys.argv[1]); rnd = random.Random(int(sys.argv[2]))
def bssid():
    f = rnd.choice(["%02x:%02x:%02x:%02x:%02x:%02x", "%x:%x:%x:%x:%x:%x", "%02X:%02X:%02X:%02X:%02X:%02X", "%02x-%02x-%02x-%02x-%02x-%02x"])
    return f % tuple(rnd.randrange(256) for _ in range(6))
def ssid():
    return rnd.choice(["", "Home", "CoffeeShop-5G", "iPhone", "héllo wörld", "日本語", "a" * 32, "x y", " ", "é"])
def ie():
    return bytes(rnd.randrange(256) for _ in range(rnd.randrange(0, 40)))
recs = []
for _ in range(n):
    r = {}
    if rnd.random() < .9:
        s = ssid(); r["SSID_STR"] = s
        if rnd.random() < .9: r["SSID"] = s.encode() if rnd.random() < .9 else ie()[:32]
    if rnd.random() < .9: r["BSSID"] = bssid()
    if rnd.random() < .95:
        r["CHANNEL"] = rnd.choice(list(range(1, 15)) + [36, 40, 44, 48, 52, 64, 100, 116, 132, 149, 153, 165] + list(range(1, 234, 4)))
        r["CHANNEL_FLAGS"] = rnd.choice([0, 2, 4, 6, 8, 10, 12, 0x10, 0x12, 0x14, 0x400, 0x410, 0x412, 0x800, 0x810, 0x2002, 0x2400, 0x2800, 0x1000, 0x20, rnd.randrange(1 << 16)])
    if rnd.random() < .9: r["RSSI"] = rnd.randrange(-100, -10)
    if rnd.random() < .8: r["NOISE"] = rnd.randrange(-110, -70)
    if rnd.random() < .9: r["BEACON_INT"] = rnd.choice([100, 102, 200, 300, 0, 1, rnd.randrange(1, 1000)])
    if rnd.random() < .3: r["AP_MODE"] = rnd.choice([0, 1, 2, 3])
    if rnd.random() < .7: r["CAPS"] = rnd.randrange(1 << 16)
    if rnd.random() < .5: r["IE"] = ie()
    if rnd.random() < .45:
        r["RSN_IE"] = {"IE_KEY_RSN_AUTHSELS": rnd.sample(range(0, 25), rnd.randrange(0, 4)), "IE_KEY_RSN_UCIPHERS": rnd.sample(range(0, 13), rnd.randrange(0, 3)), "IE_KEY_RSN_MCIPHER": rnd.randrange(0, 13)}
    if rnd.random() < .2:
        r["WPA_IE"] = {"IE_KEY_WPA_AUTHSELS": rnd.sample(range(0, 5), rnd.randrange(0, 3)), "IE_KEY_WPA_UCIPHERS": rnd.sample(range(0, 6), rnd.randrange(0, 3)), "IE_KEY_WPA_MCIPHER": rnd.randrange(0, 6)}
    for k, p in (("IOS_IE", .1), ("APPLE_P2P_IE", .05), ("HT_CAPS_IE", .5), ("VHT_CAPS", .3), ("HE_CAP", .2), ("HOTSPOT20_IE", .05)):
        if rnd.random() < p: r[k] = {}
    for k, p in (("APPLE_SWAP", .05), ("SCAN_RESULT_OWE_MULTI_SSID", .05), ("EZCONNECT", 0)):
        if rnd.random() < p: r[k] = rnd.choice([0, 1, 2])
    if rnd.random() < .25: r["80211D_IE"] = {"IE_KEY_80211D_COUNTRY_CODE": rnd.choice(["US", "DE", "JP", "RO", "XX", "", "us"])} if rnd.random() < .85 else {}
    if rnd.random() < .15:
        iw = {}
        for k, gen in (("INTERWORKING_ACCESS_NETWORK_TYPE", lambda: rnd.randrange(0, 16)), ("INTERWORKING_ACCESS_INTERNET", lambda: rnd.choice([0, 1])), ("INTERWORKING_ACCESS_HESSID", bssid), ("INTERWORKING_ACCESS_VENTURE_GRP", lambda: rnd.randrange(0, 12)), ("INTERWORKING_ACCESS_VENTURE_TYPE", lambda: rnd.randrange(0, 256)), ("INTERWORKING_ACCESS_ASRA", lambda: rnd.choice([0, 1])), ("INTERWORKING_ACCESS_ESR", lambda: rnd.choice([0, 1])), ("INTERWORKING_ACCESS_UESA", lambda: rnd.choice([0, 1]))):
            if rnd.random() < .5: iw[k] = gen()
        r["11U_INTERWORKING_IE"] = iw
    if rnd.random() < .12:
        ad = {}
        for k in ("APPLE_DEVICE_IE_FEATURE_SUPPORTS_CARPLAY", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_AIRPLAY", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_AIRPRINT", "APPLE_DEVICE_IE_FEATURE_UNCONFIGURED", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_SECURE_WAC", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_WPS", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_MFI_CONFIG_V1", "APPLE_DEVICE_IE_FEATURE_PROVIDES_INTERNET_ACCESS", "APPLE_DEVICE_IE_FEATURE_SUPPORTS_HOMEKIT"):
            if rnd.random() < .3: ad[k] = rnd.choice([True, False, 1, 0])
        if rnd.random() < .5: ad["APPLE_DEVICE_IE_FRIENDLY_NAME"] = rnd.choice(["Fred", "Printer", "", "Möbel"])
        r["APPLE_DEVICE_IE"] = ad
    if rnd.random() < .1:
        ap = {}
        if rnd.random() < .5: ap["APPLE_IE_UNCONFIGURED"] = rnd.choice([True, False])
        if rnd.random() < .5: ap["APPLE_IE_PRODUCT_ID"] = rnd.randrange(0, 1000)
        r["APPLE_IE"] = ap
    if rnd.random() < .1: r["WPS_BEACON_IE"] = {"IE_KEY_WPS_DEV_PW_ID": rnd.randrange(0, 8), "IE_KEY_WPS_SEL_REG": rnd.choice([True, False])}
    if rnd.random() < .05: r["WPS_PROB_RESP_IE"] = {"IE_KEY_WPS_DEV_PW_ID": rnd.randrange(0, 8)}
    recs.append(r)
sys.stdout.buffer.write(plistlib.dumps(recs))

/* CoreWLAN types and constants: the enumerations of the public API (values as on the Mac). */
#ifndef WSBSD_COREWLAN_TYPES_H
#define WSBSD_COREWLAN_TYPES_H
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, CWErr) {
	kCWNoErr = 0, kCWEAPOLErr = 1, kCWInvalidParameterErr = -3900, kCWNoMemoryErr = -3901, kCWUnknownErr = -3902, kCWNotSupportedErr = -3903, kCWInvalidFormatErr = -3904, kCWTimeoutErr = -3905,
	kCWUnspecifiedFailureErr = -3906, kCWUnsupportedCapabilitiesErr = -3907, kCWReassociationDeniedErr = -3908, kCWAssociationDeniedErr = -3909, kCWAuthenticationAlgorithmUnsupportedErr = -3910,
	kCWInvalidAuthenticationSequenceNumberErr = -3911, kCWChallengeFailureErr = -3912, kCWAPFullErr = -3913, kCWUnsupportedRateSetErr = -3914, kCWShortSlotUnsupportedErr = -3915,
	kCWDSSSOFDMUnsupportedErr = -3916, kCWInvalidInformationElementErr = -3917, kCWInvalidGroupCipherErr = -3918, kCWInvalidPairwiseCipherErr = -3919, kCWInvalidAKMPErr = -3920,
	kCWUnsupportedRSNVersionErr = -3921, kCWInvalidRSNCapabilitiesErr = -3922, kCWCipherSuiteRejectedErr = -3923, kCWInvalidPMKErr = -3924, kCWSupplicantTimeoutErr = -3925,
	kCWHTFeaturesNotSupportedErr = -3926, kCWPCOTransitionTimeNotSupportedErr = -3927, kCWReferenceNotBoundErr = -3928, kCWIPCFailureErr = -3929, kCWOperationNotPermittedErr = -3930, kCWErr = -3931
};
typedef NS_ENUM(NSInteger, CWPHYMode) { kCWPHYModeNone = 0, kCWPHYMode11a = 1, kCWPHYMode11b = 2, kCWPHYMode11g = 3, kCWPHYMode11n = 4, kCWPHYMode11ac = 5, kCWPHYMode11ax = 6, kCWPHYMode11be = 7 };
typedef NS_ENUM(NSInteger, CWInterfaceMode) { kCWInterfaceModeNone = 0, kCWInterfaceModeStation = 1, kCWInterfaceModeIBSS = 2, kCWInterfaceModeHostAP = 3 };
typedef NS_ENUM(NSInteger, CWSecurity) {
	kCWSecurityNone = 0, kCWSecurityWEP = 1, kCWSecurityWPAPersonal = 2, kCWSecurityWPAPersonalMixed = 3, kCWSecurityWPA2Personal = 4, kCWSecurityPersonal = 5, kCWSecurityDynamicWEP = 6,
	kCWSecurityWPAEnterprise = 7, kCWSecurityWPAEnterpriseMixed = 8, kCWSecurityWPA2Enterprise = 9, kCWSecurityEnterprise = 10, kCWSecurityWPA3Personal = 11, kCWSecurityWPA3Enterprise = 12,
	kCWSecurityWPA3Transition = 13, kCWSecurityOWE = 14, kCWSecurityOWETransition = 15, kCWSecurityUnknown = NSIntegerMax
};
typedef NS_ENUM(NSInteger, CWIBSSModeSecurity) { kCWIBSSModeSecurityNone = 0, kCWIBSSModeSecurityWEP40 = 1, kCWIBSSModeSecurityWEP104 = 2 };
typedef NS_ENUM(NSInteger, CWChannelWidth) { kCWChannelWidthUnknown = 0, kCWChannelWidth20MHz = 1, kCWChannelWidth40MHz = 2, kCWChannelWidth80MHz = 3, kCWChannelWidth160MHz = 4 };
typedef NS_ENUM(NSInteger, CWChannelBand) { kCWChannelBandUnknown = 0, kCWChannelBand2GHz = 1, kCWChannelBand5GHz = 2, kCWChannelBand6GHz = 3 };
typedef NS_OPTIONS(NSUInteger, CWCipherKeyFlags) { kCWCipherKeyFlagsNone = 0, kCWCipherKeyFlagsUnicast = (1UL << 1), kCWCipherKeyFlagsMulticast = (1UL << 2), kCWCipherKeyFlagsTx = (1UL << 3), kCWCipherKeyFlagsRx = (1UL << 4) };
typedef NS_ENUM(NSInteger, CWKeychainDomain) { kCWKeychainDomainNone = 0, kCWKeychainDomainUser = 1, kCWKeychainDomainSystem = 2 };
typedef NS_ENUM(NSInteger, CWEventType) {
	CWEventTypeNone = 0, CWEventTypePowerDidChange = 1, CWEventTypeSSIDDidChange = 2, CWEventTypeBSSIDDidChange = 3, CWEventTypeCountryCodeDidChange = 4, CWEventTypeLinkDidChange = 5,
	CWEventTypeLinkQualityDidChange = 6, CWEventTypeModeDidChange = 7, CWEventTypeScanCacheUpdated = 8, CWEventTypeBtCoexStats = 9, CWEventTypeUnknown = NSIntegerMax
};
#ifdef __cplusplus
extern "C" {
#endif
extern NSString *const CWErrorDomain;
extern NSString *const CWPowerDidChangeNotification, *const CWSSIDDidChangeNotification, *const CWBSSIDDidChangeNotification, *const CWLinkDidChangeNotification, *const CWModeDidChangeNotification,
	*const CWCountryCodeDidChangeNotification, *const CWScanCacheDidUpdateNotification, *const CWLinkQualityDidChangeNotification, *const CWLinkQualityNotificationRSSIKey, *const CWLinkQualityNotificationTransmitRateKey;
#ifdef __cplusplus
}
#endif
#endif

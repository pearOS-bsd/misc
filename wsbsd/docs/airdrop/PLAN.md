# AirDrop on wsbsd

Reference on the Mac: `/usr/libexec/sharingd` (launch agent `com.apple.sharingd`, plist copied to `airdrop/mirror/System/Library/LaunchAgents/`), client side `/System/Library/PrivateFrameworks/Sharing.framework` (inventory: `Sharing.objc.txt`, 267 classes: `SFAirDropBrowser`, `SFAirDropNode`, `SFAirDropTransfer`, `SFAirDropDiscoveryController`, the `SFAirDropInvocations.*` XPC calls ...). Mach services of sharingd: `com.apple.sharing.airdrop.service`, `com.apple.sharing.transfer-observer`, `com.apple.sharing.sharesheet`, `com.apple.SharingServices`, `com.apple.sharingd`, `com.apple.sharingd.nsxpc` ...

Protocol reference (MIT, clean room): github.com/BenItBuhner/AirDrop-for-Everything (mDNS `_airdrop._tcp`, TLS, `/Discover` `/Ask` `/Upload`, DVZip + cpio, AWDL action frames, BLE wake).

Steps: (1) inventory of sharingd (REA) and Sharing.framework [Sharing done]; (2) XPC interface of `com.apple.sharing.airdrop.service` through the NSXPC layer already in `sdk/src/XPC.m`; (3) discovery + transfer over LAN (mDNS, TLS, HTTP), then AWDL where the hardware allows; (4) `NSSharingService` AirDrop and the Finder/Sharing UI; (5) paths mirrored: `/usr/libexec/sharingd`, `/System/Library/PrivateFrameworks/Sharing.framework`.
Status: step 1 in progress.

Finding (REA, sharingd): the executable defines no AirDrop classes of its own; it imports SFAirDrop* from Sharing.framework, so the AirDrop service logic is in `Sharing.framework` (next: its SD*/Swift classes, using the dyld cache extraction).

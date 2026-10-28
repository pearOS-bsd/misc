D="$1"; P="$2"   # D = the defaults command, P = domain path
rm -f "$P.plist"; mkdir -p "$(dirname "$P")"
$D write "$P" str -string "hello world"
$D write "$P" simple -string abc
$D write "$P" num -int 42
$D write "$P" fl -float 3.5
$D write "$P" yes -bool true
$D write "$P" no -bool false
$D write "$P" arr -array a b "c d" 3
$D write "$P" dic -dict k1 v1 k2 "v 2"
$D write "$P" dic -dict-add k3 v3
$D write "$P" arr -array-add z
$D write "$P" dat -data "01020304ff"
$D write "$P" lit '{ a = 1; b = (x, y); }'
$D write "$P" NSSplitViewItemSidebarDefaultsToFloatingAppearance -bool false
$D read "$P"
for k in str num fl yes arr dic dat lit; do echo "-- $k"; $D read "$P" $k; $D read-type "$P" $k; done
$D rename "$P" simple renamed
$D delete "$P" str
$D read "$P" renamed
$D read "$P" str 2>&1 | tail -2
$D write "$P" neg -int -5
$D write "$P" fl2 -float 2.25
$D write "$P" fl3 -float 3
$D write "$P" uni -string "é x"
$D write "$P" dd -date "2026-10-29 10:11:12 +0000"
$D write "$P" big -data "000102030405060708090a0b0c0d0e0f10111213141516171819"
$D read "$P"
$D read "$P" neg; $D read "$P" dd; $D read-type "$P" dd; $D read-type "$P" yes; $D read-type "$P" fl2; $D read-type "$P" neg
$D read "$P" nokey 2>&1; $D read /tmp/dt/nosuchfile 2>&1; $D delete "$P" nokey 2>&1

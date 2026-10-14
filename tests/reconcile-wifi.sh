#!/bin/sh
set -e
umask 077
source=${1:-/usr/share/apcontroller/platforms/openwrt/setconfig}
FIX=$(mktemp -d /tmp/apc-reconcile-test.XXXXXX);export FIX
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/config" "$FIX/tmp" "$FIX/ctl";touch "$FIX/sysupgrade.conf"
cat > "$FIX/config/network" <<'EOF'
config interface 'lan'
 option proto 'none'
 option device 'eth0.1'
EOF
cat > "$FIX/config/wireless" <<'EOF'
config wifi-device 'radio0'
 option band '2g'
config wifi-iface 'keep1'
 option mode 'ap'
 option device 'radio0'
 option ssid 'OLD'
 option network 'lan'
 option apcontroller 'wifi_keep'
 option apcontroller_band '2g'
config wifi-iface 'keep2'
 option mode 'ap'
 option device 'radio0'
 option ssid 'OLD'
 option network 'lan'
 option apcontroller 'wifi_keep'
 option apcontroller_band '2g'
config wifi-iface 'local'
 option mode 'ap'
 option device 'radio0'
 option ssid 'LOCAL'
config wifi-iface 'mesh'
 option mode 'mesh'
 option device 'radio0'
 option mesh_id 'BACKHAUL'
config wifi-iface 'station'
 option mode 'sta'
 option device 'radio0'
 option ssid 'UPLINK'
config wifi-iface 'legacy'
 option mode 'ap'
 option device 'radio0'
 option ssid 'RETIRED'
EOF
cp /usr/share/apcontroller/lib/network-vlan.sh "$FIX/vlan.sh"
printf 'uci(){ /sbin/uci -c "$FIX/config" -C "$FIX/config" -t "$FIX/tmp" "$@"; }\n' > "$FIX/agent"
sed -e "s|/etc/config/|$FIX/config/|g" -e "s|/etc/apcontroller|$FIX/ctl|g" -e "s|/etc/sysupgrade.conf|$FIX/sysupgrade.conf|g" -e 's|/etc/init.d/network reload >/dev/null|true|g' -e 's|wifi reload|true|g' "$source" >> "$FIX/agent"
get(){ /sbin/uci -q -c "$FIX/config" -C "$FIX/config" -t "$FIX/tmp" get "$1"; }
printf '%s\n' '{"managed_only":1,"delete":0,"wifis":[{"id":"wifi_keep","band":"2g","network":"lan","vlan_id":"1","enabled":1,"ssid":"NEW","encryption":"none"},{"id":"wifi_new","band":"2g","network":"lan","vlan_id":"1","enabled":0,"ssid":"ADD","encryption":"none"}]}' > "$FIX/payload"
sh ${APC_TEST_TRACE:+-x} "$FIX/agent" "$FIX/payload" >/dev/null
[ "$(get wireless.keep1.ssid)" = NEW ];! get wireless.keep2 >/dev/null
new=$(/sbin/uci -q -c "$FIX/config" -C "$FIX/config" -t "$FIX/tmp" show wireless | sed -n "s/^wireless.\([^.]*\).apcontroller='wifi_new'$/\1/p")
[ -n "$new" ];[ "$(get wireless.$new.ssid)" = ADD ];[ "$(get wireless.$new.disabled)" = 1 ]
grep -q "apcontroller 'wifi_new'" "$FIX/config/wireless" || { echo 'Zmiana nie została zapisana do pliku konfiguracji' >&2;cat "$FIX/config/wireless";exit 1; }
printf '%s\n' '{"managed_only":1,"delete":0,"wifis":[],"adopt":[{"id":"wifi_retired","band":"2g","ssid":"RETIRED"}]}' > "$FIX/payload"
sh "$FIX/agent" "$FIX/payload" >/dev/null
! get wireless.keep1 >/dev/null;! get wireless.$new >/dev/null;! get wireless.legacy >/dev/null
[ "$(get wireless.local.ssid)" = LOCAL ];[ "$(get wireless.mesh.mode)" = mesh ];[ "$(get wireless.station.mode)" = sta ]
before=$(sha256sum "$FIX/config/wireless" "$FIX/config/network")
printf '%s\n' '{"managed_only":1,"delete":0,"wifis":[{"id":"bad","band":"2g","network":"missing","enabled":1,"ssid":"BAD","encryption":"none"}]}' > "$FIX/payload"
if sh "$FIX/agent" "$FIX/payload" >/dev/null 2>&1; then echo 'Nie odrzucono nieistniejącej sieci' >&2;exit 1;fi
[ "$before" = "$(sha256sum "$FIX/config/wireless" "$FIX/config/network")" ]
echo 'RECONCILE_WIFI_OK: add, rename, deletion, deduplication; unmanaged AP, mesh and STA preserved; invalid config unchanged'

# Run only during first boot of the requested firmware; use the signed APK feed.
(
umask 077
mkdir -p /etc/apcontroller
exec > /etc/apcontroller/asu-reinstall.log 2>&1
. /etc/openwrt_release
case "$DISTRIB_RELEASE" in 25.12*) ;; *) echo 'Custom packages require review for this OpenWrt release'; exit 1;; esac
arch=$(head -n 1 /etc/apk/arch)
[ "$arch" = aarch64_cortex-a53 ] || exit 1
base=https://nas.marm.pl/openwrt/ap_repos/apcontroller
tmp=$(mktemp -d /tmp/apcontroller-reinstall.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
 if wget -T 15 -q -O "$tmp/key.pem" "$base/keys/apcontroller-local.pem" && printf '@KEY_HASH@  %s\n' "$tmp/key.pem" | sha256sum -c -; then
  mkdir -p /etc/apk/keys /etc/apk/repositories.d
  cp "$tmp/key.pem" /etc/apk/keys/apcontroller-local.pem
  feed="$base/$arch/packages.adb"
  grep -qxF "$feed" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || echo "$feed" >> /etc/apk/repositories.d/customfeeds.list
  rm -f /etc/apk/repositories.d/apcontroller.list
  awk '{if ($0 ~ /^(apcontroller|luci-apcontroller|luci-app-apcontroller|luci-i18n-apcontroller-pl|multivpn-connect|luci-app-multivpn-connect)[<>=~]/) sub(/[<>=~].*/, ""); print}' /etc/apk/world > "$tmp/world"
  cp "$tmp/world" /etc/apk/world
  if apk update && apk add --upgrade luci-apcontroller luci-app-multivpn-connect sstp-client; then
   echo 'Custom packages restored from signed repository'
   for iface in $(uci -q show network | sed -n 's/^network\.\([^=]*\)=interface$/\1/p'); do
    if [ "$(uci -q get network.$iface.proto)" = sstp ] && [ "$(uci -q get network.$iface.auto)" != 0 ]; then ifdown "$iface"; ifup "$iface"; fi
   done
   exit 0
  fi
 fi
 sleep 6
done
echo 'Custom package restoration failed; see this log and retry after checking WAN/repository'
exit 1
) >/tmp/apcontroller-asu-bootstrap.log 2>&1 &

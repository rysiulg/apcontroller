#!/bin/sh
set -e
[ -z "${IPKG_INSTROOT:-}" ] || exit 0
interval=$(uci -q get apcontroller.@global[0].interval || true)
case "$interval" in ''|*[!0-9]*|0) interval=5;; esac
[ "$interval" -le 59 ] || interval=59
mkdir -p /etc/crontabs /etc/apcontroller
chmod 700 /etc/apcontroller
touch /etc/crontabs/root
awk '!/\/usr\/bin\/apcontroller([[:space:]]|$)/' /etc/crontabs/root > /etc/crontabs/root.apcontroller.tmp
printf '*/%s * * * * /usr/bin/apcontroller\n' "$interval" >> /etc/crontabs/root.apcontroller.tmp
chmod 600 /etc/crontabs/root.apcontroller.tmp
mv /etc/crontabs/root.apcontroller.tmp /etc/crontabs/root
touch /etc/sysupgrade.conf
for package in apcontroller luci-app-apcontroller luci-i18n-apcontroller-pl luci-apcontroller multivpn-connect luci-app-multivpn-connect; do apk info -L "$package" 2>/dev/null | sed -n '2,$p' | while IFS= read -r item; do case "$item" in usr/*|www/*|lib/*|etc/init.d/multivpn-connect|etc/strongswan.d/multivpn-resolve.conf|etc/strongswan.d/swanctl-client.conf) sed -i "\|^/$item$|d" /etc/sysupgrade.conf;; esac; done; done
sed -i '\|^/usr/share/apcontroller/$|d;\|^/www/luci-static/resources/view/apcontroller/$|d;\|^/www/luci-static/resources/view/multivpn-connect/$|d;\|^/usr/share/multivpn-connect/$|d;\|^/etc/init.d/apcontroller-vpn$|d;\|^/etc/init.d/multivpn-connect$|d;\|^/usr/bin/apcontroller-vpn-updown$|d;\|^/etc/apk/repositories.d/apcontroller.list$|d' /etc/sysupgrade.conf
for path in /etc/config/network /etc/config/firewall /etc/config/multivpn /etc/apk/repositories.d/customfeeds.list /etc/init.d/swanctl /etc/config/apcontroller /etc/apcontroller/ /etc/apk/keys/apcontroller-local.pem /etc/swanctl/ /etc/strongswan.d/charon/af-alg.conf; do
    grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >> /etc/sysupgrade.conf
done
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*apcontroller*
/etc/init.d/rpcd restart
/etc/init.d/cron reload
/usr/bin/apcontroller-asu
exit 0

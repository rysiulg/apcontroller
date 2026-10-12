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
for path in /etc/config/apcontroller /etc/apcontroller/ /etc/apk/repositories.d/apcontroller.list /etc/apk/keys/apcontroller-local.pem /usr/bin/apcontroller /usr/bin/apcontroller-sendconfig /usr/bin/apcontroller-dhcp-zacisze /usr/bin/apcontroller-package /usr/bin/apcontroller-vpn /usr/bin/apcontroller-vpn-updown /usr/sbin/zacisze-vpn-mode /etc/init.d/apcontroller-vpn /etc/swanctl/ /usr/libexec/rpcd/apcontroller /usr/share/apcontroller/ /www/luci-static/resources/view/apcontroller/ /usr/share/rpcd/acl.d/luci-app-apcontroller.json /usr/share/luci/menu.d/luci-app-apcontroller.json; do
    grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >> /etc/sysupgrade.conf
done
/etc/init.d/apcontroller-vpn enable
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*apcontroller*
/etc/init.d/rpcd restart
/etc/init.d/cron reload
exit 0

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
grep -qxF '/etc/apcontroller/' /etc/sysupgrade.conf || echo '/etc/apcontroller/' >> /etc/sysupgrade.conf
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*apcontroller*
/etc/init.d/rpcd restart
/etc/init.d/cron reload
exit 0

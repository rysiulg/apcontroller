#!/bin/sh
set -e
[ -z "${IPKG_INSTROOT:-}" ] || exit 0
umask 077
mkdir -p /etc/multivpn-connect
if [ -f /etc/init.d/apcontroller-vpn ]; then /etc/init.d/apcontroller-vpn disable || true; fi
# One-time migration of named profiles, leaving native interfaces and credentials intact.
ucode -e 'import {cursor} from "uci";let c=cursor();c.foreach("multivpn","vpn",p=>{if(!p.interface&&!p.name)c.delete("multivpn",p[".name"]);});c.foreach("apcontroller","vpn",p=>{let id=p[".name"];if(!c.get("multivpn",id)){c.set("multivpn",id,"vpn");for(let k,v in p)if(substr(k,0,1)!=".")c.set("multivpn",id,k,v);}});c.save("multivpn");c.commit("multivpn");'
if [ -f /etc/apcontroller/vpn-managed ] && [ ! -f /etc/multivpn-connect/vpn-managed ]; then cp /etc/apcontroller/vpn-managed /etc/multivpn-connect/vpn-managed; fi
/usr/bin/multivpn-connect apply
ucode -e 'import {cursor} from "uci";let c=cursor();c.foreach("apcontroller","vpn",p=>{if(c.get("multivpn",p[".name"]))c.delete("apcontroller",p[".name"]);});c.save("apcontroller");c.commit("apcontroller");'
for package in apcontroller luci-app-apcontroller luci-i18n-apcontroller-pl luci-apcontroller multivpn-connect luci-app-multivpn-connect; do apk info -L "$package" 2>/dev/null | sed -n '2,$p' | while IFS= read -r item; do case "$item" in usr/*|www/*|lib/*|etc/init.d/multivpn-connect|etc/strongswan.d/multivpn-resolve.conf|etc/strongswan.d/swanctl-client.conf) sed -i "\|^/$item$|d" /etc/sysupgrade.conf;; esac; done; done
sed -i '\|^/usr/share/apcontroller/$|d;\|^/www/luci-static/resources/view/apcontroller/$|d;\|^/www/luci-static/resources/view/multivpn-connect/$|d;\|^/usr/share/multivpn-connect/$|d;\|^/etc/init.d/apcontroller-vpn$|d;\|^/etc/init.d/multivpn-connect$|d;\|^/usr/bin/apcontroller-vpn-updown$|d;\|^/etc/apk/repositories.d/apcontroller.list$|d' /etc/sysupgrade.conf
for path in /etc/strongswan.d/multivpn-resolve.conf /etc/strongswan.d/swanctl-client.conf /etc/hotplug.d/iface/95-multivpn-gateway /etc/config/network /etc/config/firewall /etc/config/multivpn /etc/apk/repositories.d/customfeeds.list /etc/init.d/swanctl /etc/multivpn-connect/ /etc/swanctl/ /etc/strongswan.d/charon/af-alg.conf; do grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >> /etc/sysupgrade.conf; done
chmod 600 /etc/config/multivpn /etc/config/network
/etc/init.d/multivpn-connect enable
exit 0

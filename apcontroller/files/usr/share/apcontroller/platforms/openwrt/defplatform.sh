#!/bin/sh

#
# APController OpenWrt platform definition
# Path: /usr/share/apcontroller/lib/platforms/openwrt/defplatform.sh
#

apc_platform_openwrt_detect()
{
	cat <<'EOF'
if [ -f /etc/openwrt_release ] ||
   [ -f /etc/openwrt_version ] ||
   { [ -f /etc/os-release ] &&
     grep -qi "^[[:space:]]*ID=[\"'\"']*openwrt" /etc/os-release 2>/dev/null; } ||
   command -v ubus >/dev/null 2>&1 ||
   command -v uci >/dev/null 2>&1
then
	echo OPENWRT
fi
EOF
}
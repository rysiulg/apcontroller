#!/bin/sh

#
# APController OpenWrt platform definition
#
# Path:
#
#   /usr/share/apcontroller/platforms/openwrt/defplatform.sh
#
# Detection is executed on the remote host.
#

detect()
{
	#
	# Primary OpenWrt marker.
	#

	if [ -r /etc/openwrt_release ]; then

		. /etc/openwrt_release 2>/dev/null

		case "$DISTRIB_ID" in

			OpenWrt|openwrt|LEDE|lede)

				printf '%s\n' "openwrt"
				return 0
				;;

		esac

	fi


	#
	# Older OpenWrt systems.
	#

	if [ -r /etc/openwrt_version ]; then
		printf '%s\n' "openwrt"
		return 0
	fi


	#
	# /etc/os-release fallback.
	#

	if [ -r /etc/os-release ]; then

		if grep -qi \
			'^[[:space:]]*ID=[[:space:]]*["'\"']*openwrt' \
			/etc/os-release \
			2>/dev/null
		then

			printf '%s\n' "openwrt"
			return 0
		fi

	fi


	#
	# OpenWrt always has at least one of these in normal installations.
	#
	# Keep these only as fallback detection because they can also exist
	# on non-OpenWrt systems.
	#

	if command -v ubus >/dev/null 2>&1 &&
	   command -v uci >/dev/null 2>&1
	then

		printf '%s\n' "openwrt"
		return 0
	fi


	return 1
}


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
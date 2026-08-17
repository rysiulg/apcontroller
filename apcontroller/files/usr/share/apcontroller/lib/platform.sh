#!/bin/sh

#
# APController platform detection
#

apc_detect_platform()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"

	local out

	out="$(apc_ssh_detect \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		'
		echo "---APCONTROLLER---"

		if command -v mca-cli >/dev/null 2>&1 ||
		   command -v mca-cli-op >/dev/null 2>&1 ||
		   command -v ubntbox >/dev/null 2>&1 ||
		   command -v cfgmtd >/dev/null 2>&1 ||
		   command -v syswrapper.sh >/dev/null 2>&1 ||
		   command -v ubnt-util >/dev/null 2>&1 ||
		   [ -f /etc/ubnt_version ] ||
		   [ -f /etc/ubnt_version.info ] ||
		   [ -d /etc/ubnt ] ||
		   [ -d /etc/ubnt.d ]
		then
			echo UBIQUITI
		fi

		if [ -f /etc/openwrt_release ] ||
		   [ -f /etc/openwrt_version ] ||
		   command -v ubus >/dev/null 2>&1 ||
		   command -v uci >/dev/null 2>&1
		then
			echo OPENWRT
		fi

		if command -v cliclientd >/dev/null 2>&1 ||
		   command -v tpctl >/dev/null 2>&1 ||
		   [ -d /etc/omada ] ||
		   [ -d /etc/tplink ] ||
		   [ -d /etc/tp-link ]
		then
			echo OMADA
		fi

		if command -v hostapd >/dev/null 2>&1 ||
		   [ -d /etc/hostapd ] ||
		   [ -d /sys/class/net ]
		then
			echo GENERIC
		fi
	')"

	case "$out" in
		*UBIQUITI*)
			printf '%s\n' "ubiquiti"
			;;
		*OMADA*)
			printf '%s\n' "omada"
			;;
		*OPENWRT*)
			printf '%s\n' "openwrt"
			;;
		*GENERIC*)
			printf '%s\n' "generic"
			;;
		*)
			printf '%s\n' "unknown"
			;;
	esac
}

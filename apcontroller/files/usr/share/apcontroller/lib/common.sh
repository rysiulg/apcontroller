#!/bin/sh

#
# APController common library
# Path: /usr/share/apcontroller/lib/common.sh
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

#
# Installation root.
#
BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"

LIBFOLDER="${BASEFOLDER}/lib"
PLATFORMFOLDER="${BASEFOLDER}/platforms"
SCRIPTFOLDER="${BASEFOLDER}/scripts"

#
# Runtime/cache directory.
#
BASEPATH="${BASEPATH:-/tmp/apcontroller}"

#
# UCI configuration.
#
APC_UCI_PACKAGE="apcontroller"

#
# Debug.
#
APC_DEBUG="${APC_DEBUG:-1}"
APC_LOGFILE="${APC_LOGFILE:-/var/log/apcontroller.log}"

if command -v uci >/dev/null 2>&1; then
	local_cfg="$(uci -q get apcontroller.@global[0].debug 2>/dev/null)"
	[ -n "$local_cfg" ] && APC_DEBUG="$local_cfg"

	local_log="$(uci -q get apcontroller.@global[0].logfile 2>/dev/null)"
	[ -n "$local_log" ] && APC_LOGFILE="$local_log"
fi


###############################################################################
# MD5
###############################################################################

agent_md5()
{
	local agent="$1"

	[ -n "$agent" ] || return 1
	[ -r "$agent" ] || return 1

	md5sum "$agent" 2>/dev/null |
		awk '{print $1}'
}


###############################################################################
# CONFIG INIT
###############################################################################

apc_config_init()
{
	local value

	value="$(uci -q get "${APC_UCI_PACKAGE}.@global[0].path" 2>/dev/null)"
	[ -n "$value" ] && BASEPATH="$value"

	value="$(uci -q get "${APC_UCI_PACKAGE}.@global[0].debug" 2>/dev/null)"

	case "$value" in
		1|yes|on|true)
			APC_DEBUG=1
			;;
		0|no|off|false)
			APC_DEBUG=0
			;;
	esac

	value="$(uci -q get "${APC_UCI_PACKAGE}.@global[0].logfile" 2>/dev/null)"
	[ -n "$value" ] && APC_LOGFILE="$value"

	mkdir -p "$BASEPATH" 2>/dev/null

	apc_debug common \
		"config_init path=$BASEPATH debug=$APC_DEBUG logfile=$APC_LOGFILE"
}


###############################################################################
# DEBUG
#
# NEVER writes to stdout.
#
# Usage:
#
#   apc_debug common "message"
#   apc_debug wifi "message"
#   apc_debug client "message"
#   apc_debug wlanconfig "message"
#
###############################################################################

apc_debug()
{
	local section="$1"
	shift

	[ "${APC_DEBUG:-0}" = "1" ] || return 0
	[ -n "${APC_LOGFILE:-}" ] || return 0

	mkdir -p "$(dirname "$APC_LOGFILE")" 2>/dev/null

	printf '[%s][%s][%s] %s\n' \
		"$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" \
		"apcontroller" \
		"$section" \
		"$*" >> "$APC_LOGFILE" 2>/dev/null
}


apc_debug_value()
{
	local section="$1"
	local name="$2"
	local value="$3"

	apc_debug "$section" "$name=[$value]"
}


###############################################################################
# INIT
###############################################################################

apc_config_init
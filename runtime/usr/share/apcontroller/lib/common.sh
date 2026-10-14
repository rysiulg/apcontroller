#!/bin/sh

#
# APController common library
#
# Path:
#   /usr/share/apcontroller/lib/common.sh
#
# common.sh
[ "${APC_COMMON_LOADED:-0}" = 1 ] && return 0
APC_COMMON_LOADED=1

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

###############################################################################
# PATHS
###############################################################################

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"

LIBFOLDER="${BASEFOLDER}/lib"
PLATFORMFOLDER="${BASEFOLDER}/platforms"
SCRIPTFOLDER="${BASEFOLDER}/scripts"

#
# Runtime/cache.
#
# Can be overridden by UCI:
#
#   config global
#       option path '/var/apcontroller'
#
BASEPATH="${BASEPATH:-/var/apcontroller}"

APC_UCI_PACKAGE="apcontroller"

###############################################################################
# DEBUG
###############################################################################

APC_DEBUG="${APC_DEBUG:-1}"
APC_LOGFILE="${APC_LOGFILE:-/var/log/apcontroller.log}"

if command -v uci >/dev/null 2>&1; then

	local_cfg="$(
		uci -q get \
			"${APC_UCI_PACKAGE}.@global[0].debug" \
			2>/dev/null || true
	)"

	[ -n "$local_cfg" ] && APC_DEBUG="$local_cfg"

	local_log="$(
		uci -q get \
			"${APC_UCI_PACKAGE}.@global[0].logfile" \
			2>/dev/null || true
	)"

	[ -n "$local_log" ] && APC_LOGFILE="$local_log"

	local_path="$(
		uci -q get \
			"${APC_UCI_PACKAGE}.@global[0].path" \
			2>/dev/null || true
	)"

	[ -n "$local_path" ] && BASEPATH="$local_path"

fi


apc_config_init()
{
	local path
	local debug
	local logfile

	path="$BASEPATH"
	debug="$APC_DEBUG"
	logfile="$APC_LOGFILE"

	mkdir -p "$path" 2>/dev/null

	#
	# UCI configuration can override defaults.
	#
	if command -v uci >/dev/null 2>&1; then

		path="$(uci -q get apcontroller.@global[0].path 2>/dev/null || true)"
		[ -n "$path" ] || path="$BASEPATH"

		debug="$(uci -q get apcontroller.@global[0].debug 2>/dev/null || true)"
		[ -n "$debug" ] || debug="$APC_DEBUG"

		logfile="$(uci -q get apcontroller.@global[0].logfile 2>/dev/null || true)"
		[ -n "$logfile" ] || logfile="$APC_LOGFILE"

	fi

	BASEPATH="$path"
	APC_DEBUG="$debug"
	APC_LOGFILE="$logfile"

	mkdir -p "$BASEPATH" 2>/dev/null

	apc_debug common \
		"config_init path=$BASEPATH debug=$APC_DEBUG logfile=$APC_LOGFILE"
}


###############################################################################
# DEBUG
###############################################################################

apc_debug()
{
	local component="$1"
	shift

	[ "$APC_DEBUG" = "1" ] || return 0

	local message
	message="$*"

	local line
	line="[$(date '+%Y-%m-%d %H:%M:%S')][apcontroller][$component] $message"

	#printf '%s\n' "$line" >&2

	if [ -n "$APC_LOGFILE" ]; then
		printf '%s\n' "$line" >> "$APC_LOGFILE" 2>/dev/null
	fi
}


###############################################################################
# ERROR
###############################################################################

apc_error()
{
	local component="$1"
	shift

	local message
	message="$*"

	local line
	line="[$(date '+%Y-%m-%d %H:%M:%S')][apcontroller][$component][ERROR] $message"

	#printf '%s\n' "$line" >&2

	if [ -n "$APC_LOGFILE" ]; then
		printf '%s\n' "$line" >> "$APC_LOGFILE" 2>/dev/null
	fi
}


###############################################################################
# FILE HELPERS
###############################################################################

apc_mkdir()
{
	[ -n "$1" ] || return 1

	mkdir -p "$1" 2>/dev/null
}


apc_atomic_write()
{
	local file="$1"
	local tmp="$2"

	[ -n "$file" ] || return 1
	[ -n "$tmp" ] || return 1

	cat > "$tmp" || return 1

	mv "$tmp" "$file"
}


###############################################################################
# STRING HELPERS
###############################################################################

apc_lower()
{
	printf '%s' "$1" |
		awk '{print tolower($0)}'
}

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
# JSON
###############################################################################

json_escape()
{
	local input="$1"

	printf '%s' "$input" |
		awk '
		BEGIN { ORS="" }
		{
			gsub(/\\/, "\\\\");
			gsub(/"/, "\\\"");
			gsub(/\t/, "\\t");
			gsub(/\r/, "\\r");
			gsub(/\n/, "\\n");
			printf "%s", $0;
		}'
}


json_string()
{
	printf '"%s"' "$(json_escape "$1")"
}


json_number()
{
	case "$1" in

		''|*[!0-9-]*)
			printf '0'
			;;

		*)
			printf '%s' "$1"
			;;

	esac
}


json_boolean()
{
	case "$1" in

		1|true|TRUE|yes|on)
			printf 'true'
			;;

		*)
			printf 'false'
			;;

	esac
}


###############################################################################
# EMPTY HOST
###############################################################################

empty_host_json()
{
	cat <<'EOF'
{
	"mac":"",
	"hostname":"",
	"model":"",
	"software":"",
	"uptime":0,
	"load":"",
	"wifi":[],
	"clientslist2g":[],
	"clientslist5g":[],
	"clientslist6g":[]
}
EOF
}


###############################################################################
# INIT
###############################################################################

if [ "${APC_STANDALONE:-0}" != "1" ]; then
    apc_config_init
fi

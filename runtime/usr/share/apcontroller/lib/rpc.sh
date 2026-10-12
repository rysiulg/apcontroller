#!/bin/sh

#
# APController RPC/backend library
# Path:
#   /usr/share/apcontroller/lib/rpc.sh
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"

LIBFOLDER="${BASEFOLDER}/lib"
SCRIPTFOLDER="${BASEFOLDER}/scripts"

. "${LIBFOLDER}/common.sh"
. "${LIBFOLDER}/platform.sh"
. /lib/functions.sh


###############################################################################
# JSON HELPERS
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
# NORMALIZE AGENT OUTPUT
###############################################################################

normalize_agent_output()
{
	local input="$1"

	if [ -n "$input" ] &&
		printf '%s' "$input" |
		jsonfilter -q -e '@' >/dev/null 2>&1
	then

		printf '%s\n' "$input"

		return 0
	fi

	empty_host_json

	return 0
}


###############################################################################
# HOST PLATFORM CACHE
###############################################################################

apc_host_set_platform()
{
	local cfg="$1"
	local platform="$2"

	[ -n "$cfg" ] || return 1
	[ -n "$platform" ] || return 1

	uci set "apcontroller.${cfg}.platform=${platform}"
}


apc_host_set_agent_version()
{
	local cfg="$1"
	local version="$2"

	[ -n "$cfg" ] || return 1
	[ -n "$version" ] || return 0

	uci set "apcontroller.${cfg}.agent_version=${version}"
}


apc_host_commit()
{
	uci commit apcontroller
}


###############################################################################
# AGENT VERSION
###############################################################################

apc_extract_agent_version()
{
	local data="$1"
	local version

	version="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.agent_version' \
			2>/dev/null
	)"

	[ -n "$version" ] || return 1

	printf '%s\n' "$version"

	return 0
}


###############################################################################
# VALIDATE HOST RESPONSE
###############################################################################

apc_validate_host_response()
{
	local file="$1"
	local data

	[ -s "$file" ] || return 1

	data="$(cat "$file" 2>/dev/null)"

	[ -n "$data" ] || return 1

	printf '%s' "$data" |
		jsonfilter -q -e '@' \
		>/dev/null 2>&1 ||
		return 1

	printf '%s' "$data" |
		jsonfilter -q -e '@.mac' \
		>/dev/null 2>&1 ||
		return 1

	return 0
}

###############################################################################
# ONLINE STATE
###############################################################################

apc_host_set_online()
{
	local ipaddr="$1"
	local value="$2"

	[ -n "$ipaddr" ] || return 1

	case "$value" in
		0|1)
			;;
		*)
			value=0
			;;
	esac

	printf '%s\n' "$value=0 && '0' || '1'" > "${BASEPATH}/${ipaddr}.online"
}


apc_host_set_contact()
{
	local ipaddr="$1"
	local timestamp

	[ -n "$ipaddr" ] || return 1

	timestamp="$(date +%s)"

	printf '%s\n' "$timestamp" \
		> "${BASEPATH}/${ipaddr}.lastcontact"
}

###############################################################################
# POLL HOST
###############################################################################

get_data_from_host()
{
	local cfg="$1"

	local enabled
	local ipaddr
	local username
	local password
	local port
	local usekeyfile
	local keyfile

	local platform
	local configured_platform
	local configured_agent_version
	local agent_version

	local api_url
	local api_method
	local api_token

	local output
	local tmpoutput

	local now
	local val
	local timestamp
	local d
    local onlinefile

	local ret


	###########################################################################
	# CONFIG
	###########################################################################

	config_get_bool enabled "$cfg" enabled 1

	[ "$enabled" -gt 0 ] || return 0

	config_get ipaddr "$cfg" ipaddr
	config_get username "$cfg" username

	[ -n "$ipaddr" ] || return 0
	[ -n "$username" ] || return 0

	config_get password "$cfg" password
	config_get port "$cfg" port 22

	config_get usekeyfile "$cfg" usekeyfile 0
	config_get keyfile "$cfg" keyfile "/root/.ssh/id_dropbear"

	config_get configured_platform "$cfg" platform ""
	config_get configured_agent_version "$cfg" agent_version ""

	config_get api_url "$cfg" api_url ""
	config_get api_method "$cfg" api_method "GET"
	config_get api_token "$cfg" api_token ""


	###########################################################################
	# LOG
	###########################################################################

	apc_debug rpc \
		"poll host=$cfg ip=$ipaddr port=$port configured_platform=${configured_platform:-auto}"


	###########################################################################
	# PLATFORM
	###########################################################################

	if [ -n "$configured_platform" ] &&
		[ "$configured_platform" != "auto" ] &&
		[ "$configured_platform" != "unknown" ]
	then

		platform="$configured_platform"

		apc_debug rpc \
			"using cached platform=$platform host=$ipaddr"

	else

		platform="$(
			apc_platform_detect \
				"$ipaddr" \
				"$port" \
				"$username" \
				"$password" \
				"$keyfile" \
				"$usekeyfile"
		)"

		platform="$(
			printf '%s' "$platform" |
			awk '{print tolower($0)}'
		)"

		[ -n "$platform" ] || platform="unknown"

	fi


	###########################################################################
	# CACHE
	###########################################################################

	output="${BASEPATH}/${ipaddr}-${cfg}"
	tmpoutput="${output}.tmp"
	onlinefile="${BASEPATH}/${ipaddr}-${cfg}.online"

	rm -f "$tmpoutput"


	printf '%s\n' "$platform" \
		> "${output}.platform"


	###########################################################################
	# UNKNOWN
	###########################################################################

	if [ "$platform" = "unknown" ]; then

		apc_debug rpc \
			"no platform available host=$ipaddr"

		empty_host_json > "$output"

		return 0
	fi


	###########################################################################
	# EXECUTE
	#
	# platform.sh:
	#
	#   HTTP
	#      ↓
	#   SSH agent
	#      ↓
	#   HTTP retry
	#
	###########################################################################

	apc_platform_execute \
		"$platform" \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"poll" \
		"$tmpoutput" \
		"$api_url" \
		"$api_method" \
		"$api_token"

	ret=$?


	###########################################################################
	# VALIDATE
	###########################################################################

	if [ "$ret" -eq 0 ] &&
		[ -s "$tmpoutput" ] &&
		apc_validate_host_response "$tmpoutput"
	then
		date +%s > "${onlinefile}.tmp"
		mv "${onlinefile}.tmp" "$onlinefile"

		apc_debug rpc \
			"executor validated host=$ipaddr platform=$platform bytes=$(wc -c < "$tmpoutput")"


		########################################################################
		# PLATFORM CACHE
		########################################################################

		if [ "$configured_platform" != "$platform" ]; then

			apc_host_set_platform \
				"$cfg" \
				"$platform"

		fi


		########################################################################
		# AGENT VERSION
		########################################################################

		agent_version="$(
			apc_extract_agent_version \
				"$(cat "$tmpoutput")"
		)"


		if [ -n "$agent_version" ] &&
			[ "$configured_agent_version" != "$agent_version" ]
		then

			apc_host_set_agent_version \
				"$cfg" \
				"$agent_version"

		fi


		########################################################################
		# COMMIT
		########################################################################

		if [ "$configured_platform" != "$platform" ] ||
			{
				[ -n "$agent_version" ] &&
				[ "$configured_agent_version" != "$agent_version" ]
			}
		then

			apc_host_commit

		fi


		mv "$tmpoutput" "$output"


	else

		apc_debug rpc \
			"executor failed or invalid response host=$ipaddr platform=$platform ret=$ret"

		rm -f "$tmpoutput"

		empty_host_json > "$output"

	fi


	rm -f "$tmpoutput"


	###########################################################################
	# ONLINE STATE
	###########################################################################

	now="$(date +%s)"

	if [ "$ret" -eq 0 ] &&
		[ -s "$output" ] &&
		apc_validate_host_response "$output"
	then

		#
		# Successful poll.
		#
		apc_host_set_online "$ipaddr" 1
		apc_host_set_contact "$ipaddr"

		val=1

	else

		#
		# Failed poll.
		#
		apc_host_set_online "$ipaddr" 0

		val=0

	fi


	###########################################################################
	# ONLINE HISTORY
	###########################################################################

	now="$(
		date +%s -d \
		"$(date -d @"$now" "+%Y-%m-%d %H:00")"
	)"

	touch "${BASEPATH}/${ipaddr}.txt"

	grep -q "^${now} ${val}$" \
		"${BASEPATH}/${ipaddr}.txt" \
		2>/dev/null ||
		echo "$now $val" >> "${BASEPATH}/${ipaddr}.txt"

	return 0
}


###############################################################################
# HOST CACHE
###############################################################################

host_json()
{
	local cfg="$1"
	local ipaddr="$2"

	if [ -n "$ipaddr" ] &&
		[ -s "${BASEPATH}/${ipaddr}-${cfg}" ]
	then

		cat "${BASEPATH}/${ipaddr}-${cfg}"

	else

		empty_host_json

	fi
}


###############################################################################
# CHANNELS
###############################################################################

derive_channels()
{
	local data="$1"
	local band="$2"

	local i
	local item
	local item_band
	local item_channel
	local result=""

	i=0

	while :; do

		item="$(
			printf '%s' "$data" |
			jsonfilter -q \
				-e "@.wifi[$i]" \
				2>/dev/null
		)"

		[ -n "$item" ] || break

		item_band="$(
			printf '%s' "$item" |
			jsonfilter -q \
				-e '@.band' \
				2>/dev/null
		)"

		item_channel="$(
			printf '%s' "$item" |
			jsonfilter -q \
				-e '@.channel' \
				2>/dev/null
		)"

		if [ "$item_band" = "$band" ]; then

			case "$item_channel" in

				''|0)
					;;

				*)

					case " $result " in

						*" $item_channel "*)
							;;

						*)

							if [ -n "$result" ]; then
								result="$result $item_channel"
							else
								result="$item_channel"
							fi

							;;

					esac

					;;

			esac

		fi

		i=$((i + 1))

	done

	printf '%s' "$result"
}


###############################################################################
# BUILD HOST
###############################################################################

build_one_host()
{
	local cfg="$1"

	local ipaddr
	local name
	local enabled
	local platform
	local data
	local wifi

	local cache
	local now
	local ts
	local lastcontact

	local mac
	local hostname
	local model
	local software
	local uptime
	local load

	local channels2g
	local channels5g
	local channels6g

	local clients2g
	local clients5g
	local clients6g


	config_get ipaddr "$cfg" ipaddr
	config_get name "$cfg" name
	config_get_bool enabled "$cfg" enabled 1

	[ -n "$ipaddr" ] || return 0


	platform="$(
		cat "${BASEPATH}/${ipaddr}-${cfg}.platform" \
		2>/dev/null
	)"

	[ -n "$platform" ] || platform="unknown"


	data="$(
		host_json \
			"$cfg" \
			"$ipaddr" \
			2>/dev/null
	)"


	[ -n "$data" ] ||
		data="$(empty_host_json)"


	lastcontact=-1

	cache="${BASEPATH}/${ipaddr}-${cfg}"
	###########################################################################
	# ONLINE
	###########################################################################

	online=0

	if [ "$enabled" = "1" ] &&
		[ -r "${BASEPATH}/${ipaddr}.online" ]
	then

		online="$(
			cat "${BASEPATH}/${ipaddr}.online" 2>/dev/null
		)"

		case "$online" in
			1)
				;;
			*)
				online=0
				;;
		esac

	fi
	if [ "$enabled" = "1" ] &&
		[ -r "${BASEPATH}/${ipaddr}.lastcontact" ]
	then

		now="$(date +%s)"

		ts="$(
			cat "${BASEPATH}/${ipaddr}.lastcontact" \
				2>/dev/null
		)"

		case "$ts" in

			''|*[!0-9]*)
				lastcontact=-1
				;;

			*)
				lastcontact=$((now - ts))

				[ "$lastcontact" -lt 0 ] &&
					lastcontact=0
				;;

		esac

	fi



	mac="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.mac' \
			2>/dev/null
	)"


	hostname="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.hostname' \
			2>/dev/null
	)"


	model="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.model' \
			2>/dev/null
	)"


	software="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.software' \
			2>/dev/null
	)"


	uptime="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.uptime' \
			2>/dev/null
	)"


	load="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.load' \
			2>/dev/null
	)"


	wifi="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.wifi' \
			2>/dev/null
	)"


	[ -n "$wifi" ] || wifi='[]'


	channels2g="$(derive_channels "$data" "2g")"
	channels5g="$(derive_channels "$data" "5g")"
	channels6g="$(derive_channels "$data" "6g")"


	clients2g="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.clientslist2g' \
			2>/dev/null
	)"


	clients5g="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.clientslist5g' \
			2>/dev/null
	)"


	clients6g="$(
		printf '%s' "$data" |
		jsonfilter -q \
			-e '@.clientslist6g' \
			2>/dev/null
	)"


	[ -n "$clients2g" ] || clients2g='[]'
	[ -n "$clients5g" ] || clients5g='[]'
	[ -n "$clients6g" ] || clients6g='[]'


	case "$uptime" in

		''|*[!0-9-]*)
			uptime=0
			;;

	esac


	printf '{'

	printf '"section":%s,' \
		"$(json_string "$cfg")"

	printf '"enabled":%s,' \
		"$(json_boolean "$enabled")"

	printf '"online":%s,' \
		"$(json_number "$online")"

	printf '"name":%s,' \
		"$(json_string "$name")"

	printf '"ipaddr":%s,' \
		"$(json_string "$ipaddr")"

	printf '"platform":%s,' \
		"$(json_string "$platform")"

	printf '"hostname":%s,' \
		"$(json_string "$hostname")"

	printf '"model":%s,' \
		"$(json_string "$model")"

	printf '"load":%s,' \
		"$(json_string "$load")"

	printf '"uptime":%s,' \
		"$(json_number "$uptime")"

	printf '"mac":%s,' \
		"$(json_string "$mac")"

	printf '"software":%s,' \
		"$(json_string "$software")"

	printf '"channels2g":%s,' \
		"$(json_string "$channels2g")"

	printf '"channels5g":%s,' \
		"$(json_string "$channels5g")"

	printf '"channels6g":%s,' \
		"$(json_string "$channels6g")"

	printf '"wifi":%s,' \
		"$wifi"

	printf '"clientslist2g":%s,' \
		"$clients2g"

	printf '"clientslist5g":%s,' \
		"$clients5g"

	printf '"clientslist6g":%s,' \
		"$clients6g"

	printf '"lastcontact":%s' \
		"$(json_number "$lastcontact")"

	printf '}'
}


###############################################################################
# HOST LIST
###############################################################################

build_hosts_foreach()
{
	local cfg="$1"
	local item

	item="$(
		build_one_host "$cfg" \
		2>/dev/null
	)"

	[ -n "$item" ] || return 0

	if [ "$BUILD_HOSTS_FIRST" -eq 0 ]; then
		printf ','
	fi

	printf '%s' "$item"

	BUILD_HOSTS_FIRST=0
}


build_hosts()
{
	BUILD_HOSTS_FIRST=1

	printf '['

	config_load apcontroller

	config_foreach \
		build_hosts_foreach \
		host

	printf ']'
}


###############################################################################
# RPC STATUS
###############################################################################

rpc_status()
{
	apc_debug rpc \
		"status request"

	config_load apcontroller

	printf '{"hosts":'

	build_hosts

	printf '}\n'
}


###############################################################################
# RPC ACTIVITY
###############################################################################

rpc_activity()
{
	local input
	local section
	local ipaddr
	local file

	local first=1
	local timestamp
	local value


	input="$(cat)"


	section="$(
		printf '%s' "$input" |
		jsonfilter -q \
			-e '@.section' \
			2>/dev/null
	)"


	[ -n "$section" ] || {

		printf '{"activity":[]}\n'

		return 0
	}


	config_load apcontroller

	config_get ipaddr "$section" ipaddr


	[ -n "$ipaddr" ] || {

		printf '{"activity":[]}\n'

		return 0
	}


	file="${BASEPATH}/${ipaddr}.txt"

	printf '{"activity":['


	if [ -f "$file" ]; then

		while read -r timestamp value; do

			[ -n "$timestamp" ] || continue
			[ -n "$value" ] || value=0

			if [ "$first" -eq 0 ]; then
				printf ','
			fi

			first=0

			printf '{"timestamp":%s,"value":%s}' \
				"$(json_number "$timestamp")" \
				"$(json_number "$value")"

		done < "$file"

	fi


	printf ']}\n'
}


###############################################################################
# RPC SCRIPTS
###############################################################################

rpc_scripts()
{
	local first=1
	local file
	local filename
	local description
	local warn


	printf '{"scripts":['


	for file in "${SCRIPTFOLDER}"/*; do

		[ -f "$file" ] || continue

		filename="$(basename "$file")"
		description="$filename"
		warn=0


		if grep -q \
			'^# APController-Warn:[[:space:]]*1' \
			"$file" \
			2>/dev/null
		then

			warn=1

		fi


		if [ "$first" -eq 0 ]; then
			printf ','
		fi

		first=0


		printf '{"file":%s,"description":%s,"warn":%s}' \
			"$(json_string "$filename")" \
			"$(json_string "$description")" \
			"$warn"

	done


	printf ']}\n'
}

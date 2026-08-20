#!/bin/sh

#
# APController rpcd backend
# /usr/share/apcontroller/lib/platform.sh
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"
LIBFOLDER="${BASEFOLDER}/lib"

. "${LIBFOLDER}/common.sh"
. "${LIBFOLDER}/ssh.sh"
. /lib/functions.sh


###############################################################################
# JSON HELPERS
###############################################################################

json_escape()
{
	printf '%s' "$1" |
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
		1|true|TRUE|yes)
			printf 'true'
			;;
		*)
			printf 'false'
			;;
	esac
}


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
# PLATFORM DETECTION
###############################################################################

apc_platform_detect()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"

	local file
	local platform
	local detector
	local command
	local result

	[ -n "$ipaddr" ] || return 1
	[ -n "$username" ] || return 1

	for file in "${PLATFORMFOLDER}"/*/defplatform.sh; do

		[ -f "$file" ] || continue

		platform="$(basename "$(dirname "$file")")"

		. "$file"

		detector="apc_platform_${platform}_detect"

		type "$detector" >/dev/null 2>&1 || continue

		apc_debug platform \
			"trying platform=$platform host=$ipaddr"


		############################################################################
		# LOCAL / INTERACTIVE DETECTOR
		############################################################################

		local_detector="apc_platform_${platform}_detect_local"

		if type "$local_detector" >/dev/null 2>&1; then

			apc_debug platform \
				"trying local detector platform=$platform host=$ipaddr"

			result="$(
				"$local_detector" \
					"$ipaddr" \
					"$port" \
					"$username" \
					"$password" \
					"$keyfile" \
					"$usekeyfile"
			)"

			if [ -n "$result" ]; then

				apc_debug platform \
					"detected platform=$platform host=$ipaddr result=$result"

				printf '%s\n' "$platform"
				return 0
			fi

			continue
		fi


		############################################################################
		# NORMAL REMOTE SHELL DETECTOR
		############################################################################

		command="$("$detector")"

		[ -n "$command" ] || continue

		result="$(
			apc_ssh \
				"$platform" \
				"$ipaddr" \
				"$port" \
				"$username" \
				"$password" \
				"$keyfile" \
				"$usekeyfile" \
				"sh -s" \
				<<EOF
$command
EOF
		)"

		if [ -n "$result" ]; then

			apc_debug platform \
				"detected platform=$platform host=$ipaddr result=$result"

			printf '%s\n' "$platform"
			return 0
		fi
	done

	apc_debug platform \
		"no platform detected host=$ipaddr"

	return 1
}


###############################################################################
# AGENT OUTPUT
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
}


###############################################################################
# PLATFORM AGENT
###############################################################################

apc_platform_agent()
{
	local platform="$1"

	case "$platform" in

		openwrt|OPENWRT)
			[ -f "${PLATFORMFOLDER}/openwrt/agent" ] &&
				printf '%s\n' "${PLATFORMFOLDER}/openwrt/agent"
			;;

		omada|OMADA)
			[ -f "${PLATFORMFOLDER}/omada/agent" ] &&
				printf '%s\n' "${PLATFORMFOLDER}/omada/agent"
			;;

		ubiquiti|UBIQUITI)
			[ -f "${PLATFORMFOLDER}/ubiquiti/agent" ] &&
				printf '%s\n' "${PLATFORMFOLDER}/ubiquiti/agent"
			;;

		mikrotik|MIKROTIK)
			[ -f "${PLATFORMFOLDER}/mikrotik/agent" ] &&
				printf '%s\n' "${PLATFORMFOLDER}/mikrotik/agent"
			;;

		*)
			return 1
			;;
	esac
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
	local agent

	local output
	local tmpoutput

	local now
	local val
	local timestamp
	local d
	local ret

	local tmperr

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


	############################################################################
	# PLATFORM
	############################################################################

	apc_debug rpc \
		"poll host=$cfg ip=$ipaddr port=$port configured_platform=${configured_platform:-auto}"

	if [ -n "$configured_platform" ] &&
		[ "$configured_platform" != "auto" ]
	then

		platform="$configured_platform"

		apc_debug rpc \
			"using configured platform=$platform host=$ipaddr"

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

		platform="$(printf '%s' "$platform" | awk '{print tolower($0)}')"

		[ -n "$platform" ] || platform="unknown"
	fi


	############################################################################
	# AGENT
	############################################################################

	agent="$(apc_platform_agent "$platform")"

	apc_debug rpc \
		"host=$cfg detected_platform=$platform agent=${agent:-none}"


	############################################################################
	# CACHE
	############################################################################

	output="${BASEPATH}/${ipaddr}-${cfg}"
	tmpoutput="${output}.tmp"
	tmperr="${output}.err"
	rm -f "$tmperr"

	rm -f "$tmpoutput"


	printf '%s\n' "$platform" \
		> "${BASEPATH}/${ipaddr}-${cfg}.platform"


	############################################################################
	# NO AGENT
	############################################################################

	if [ -z "$agent" ]; then

		apc_debug rpc \
			"no agent available platform=$platform host=$ipaddr"

		empty_host_json > "$output"

		return 0
	fi


	if [ ! -f "$agent" ]; then

		apc_debug rpc \
			"agent not found platform=$platform agent=$agent"

		empty_host_json > "$output"

		return 0
	fi


	############################################################################
	# OMADA
	############################################################################

	if [ "$platform" = "omada" ]; then

		apc_debug rpc \
			"execute local agent=$agent host=$ipaddr"

		chmod +x "$agent" 2>/dev/null

		"$agent" \
			poll \
			"$ipaddr" \
			"$port" \
			"$username" \
			"$password" \
			"$usekeyfile" \
			"$keyfile" \
			> "$tmpoutput" \
			2>/dev/null

		ret=$?

	else

		############################################################################
		# REMOTE AGENT
		############################################################################

		apc_debug rpc \
			"upload agent=$agent host=$ipaddr platform=$platform"

		if apc_scp \
			"$platform" \
			"$ipaddr" \
			"$port" \
			"$username" \
			"$password" \
			"$keyfile" \
			"$usekeyfile" \
			"$agent" \
			"/tmp/apcontroller-agent"
		then

			apc_debug rpc \
                                "execute remote agent host=$ipaddr platform=$platform"

                        : > "$tmpoutput"
                        : > "$tmperr"

                        apc_ssh \
                                "$platform" \
                                "$ipaddr" \
                                "$port" \
                                "$username" \
                                "$password" \
                                "$keyfile" \
                                "$usekeyfile" \
                                "chmod +x /tmp/apcontroller-agent; /tmp/apcontroller-agent" \
                                > "$tmpoutput" \
                                2> "$tmperr"

                        ret=$?

                        outbytes="$(wc -c < "$tmpoutput" 2>/dev/null)"
                        errbytes="$(wc -c < "$tmperr" 2>/dev/null)"

                        apc_debug rpc \
                                "EXEC END host=$ipaddr platform=$platform ret=$ret stdout_bytes=$outbytes stderr_bytes=$errbytes"

                        if [ -s "$tmperr" ]; then
                                apc_debug rpc \
                                        "AGENT STDERR host=$ipaddr platform=$platform: $(cat "$tmperr")"
                        fi

                        if [ -s "$tmpoutput" ]; then
                                apc_debug rpc \
                                        "AGENT STDOUT host=$ipaddr platform=$platform: $(head -c 1000 "$tmpoutput")"
                        fi

                        #
                        # Cleanup MUST NOT touch tmpoutput.
                        #
                        apc_ssh \
                                "$platform" \
                                "$ipaddr" \
                                "$port" \
                                "$username" \
                                "$password" \
                                "$keyfile" \
                                "$usekeyfile" \
                                "rm -f /tmp/apcontroller-agent" \
                                >/dev/null 2>&1

		else

			apc_debug rpc \
				"agent upload failed host=$ipaddr platform=$platform"

			ret=1
		fi
	fi


	############################################################################
	# VALIDATE AGENT RESULT
	############################################################################

	if [ "$ret" -eq 0 ] && [ -s "$tmpoutput" ]; then

		if jsonfilter -q \
			-i "$tmpoutput" \
			-e '@' >/dev/null 2>&1
		then

			normalize_agent_output \
				"$(cat "$tmpoutput")" \
				> "$output"

		else

			apc_debug rpc \
				"invalid agent JSON host=$ipaddr platform=$platform"

			empty_host_json > "$output"
		fi

	else

		apc_debug rpc \
			"agent failed host=$ipaddr platform=$platform ret=$ret"

		empty_host_json > "$output"
	fi


	rm -f "$tmpoutput"


	############################################################################
	# ONLINE HISTORY
	############################################################################

	now="$(date +%s)"
	val=0

	if [ -s "$output" ]; then

		timestamp="$(date +%s -r "$output" 2>/dev/null)"

		if [ -n "$timestamp" ]; then

			d=$((now - timestamp))

			[ "$d" -le 60 ] && val=1
		fi
	fi


	now="$(date +%s -d "$(date -d @"$now" "+%Y-%m-%d %H:00")")"

	touch "${BASEPATH}/${ipaddr}.txt"

	grep -q "^${now} ${val}$" \
		"${BASEPATH}/${ipaddr}.txt" 2>/dev/null ||
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
# DERIVE CHANNEL LIST FROM WIFI
#
# Agent returns:
#
#   wifi:[ ... ]
#
# Therefore channels2g/5g/6g are derived here.
#
###############################################################################

wifi_channels()
{
	local wifi="$1"
	local band="$2"

	[ -n "$wifi" ] || {
		printf '%s' ""
		return 0
	}

	printf '%s' "$wifi" |
		jsonfilter -q -e '@[*]' 2>/dev/null |
		awk -v band="$band" '
		{
			#
			# jsonfilter output is not guaranteed to be one object
			# per line, so this helper is intentionally conservative.
			#
		}'
}


derive_channels()
{
	local data="$1"
	local band="$2"

	local wifi
	local result
	local ch

	wifi="$(printf '%s' "$data" |
		jsonfilter -q -e '@.wifi' 2>/dev/null)"

	[ -n "$wifi" ] || {
		printf '%s' ""
		return 0
	}


	result="$(
		printf '%s' "$wifi" |
		jsonfilter -q -e '@[*].channel' 2>/dev/null |
		tr '\n' ' '
	)"


	#
	# We need the band as well. Extract complete wifi objects and
	# use jsonfilter indexes.
	#

	local count
	local i
	local item
	local item_band
	local item_channel

	count="$(
		printf '%s' "$wifi" |
		jsonfilter -q -e '@[*]' 2>/dev/null |
		wc -l
	)"

	#
	# BusyBox/jsonfilter differs between OpenWrt versions.
	# The robust method is to use the original JSON and query
	# individual array entries until no item exists.
	#

	result=""

	i=0

	while :; do

		item="$(
			printf '%s' "$data" |
			jsonfilter -q -e "@.wifi[$i]" 2>/dev/null
		)"

		[ -n "$item" ] || break

		item_band="$(
			printf '%s' "$item" |
			jsonfilter -q -e '@.band' 2>/dev/null
		)"

		item_channel="$(
			printf '%s' "$item" |
			jsonfilter -q -e '@.channel' 2>/dev/null
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
# BUILD ONE HOST
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

	local lastcontact
	local cache
	local now
	local ts

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


	############################################################################
	# CONFIG
	############################################################################

	config_get ipaddr "$cfg" ipaddr
	config_get name "$cfg" name
	config_get_bool enabled "$cfg" enabled 1

	[ -n "$ipaddr" ] || return 0


	############################################################################
	# PLATFORM
	############################################################################

	platform="$(
		cat "${BASEPATH}/${ipaddr}-${cfg}.platform" 2>/dev/null
	)"

	[ -n "$platform" ] || platform="unknown"


	############################################################################
	# DATA
	############################################################################

	data="$(host_json "$cfg" "$ipaddr" 2>/dev/null)"

	[ -n "$data" ] || data="$(empty_host_json)"


	############################################################################
	# LAST CONTACT
	############################################################################

	lastcontact=-1

	cache="${BASEPATH}/${ipaddr}-${cfg}"

	if [ "$enabled" = "1" ] && [ -s "$cache" ]; then

		now="$(date +%s)"
		ts="$(date +%s -r "$cache" 2>/dev/null)"

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


	############################################################################
	# SCALARS
	############################################################################

	mac="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.mac' 2>/dev/null
	)"

	hostname="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.hostname' 2>/dev/null
	)"

	model="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.model' 2>/dev/null
	)"

	software="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.software' 2>/dev/null
	)"

	uptime="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.uptime' 2>/dev/null
	)"

	load="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.load' 2>/dev/null
	)"


	############################################################################
	# WIFI
	############################################################################

	wifi="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.wifi' 2>/dev/null
	)"

	[ -n "$wifi" ] || wifi='[]'


	############################################################################
	# CHANNELS
	#
	# Do NOT read channels2g/5g/6g from agent anymore.
	# Derive them from wifi[].
	############################################################################

	channels2g="$(derive_channels "$data" "2g")"
	channels5g="$(derive_channels "$data" "5g")"
	channels6g="$(derive_channels "$data" "6g")"


	############################################################################
	# CLIENTS
	############################################################################

	clients2g="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.clientslist2g' 2>/dev/null
	)"

	clients5g="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.clientslist5g' 2>/dev/null
	)"

	clients6g="$(
		printf '%s' "$data" |
		jsonfilter -q -e '@.clientslist6g' 2>/dev/null
	)"

	[ -n "$clients2g" ] || clients2g='[]'
	[ -n "$clients5g" ] || clients5g='[]'
	[ -n "$clients6g" ] || clients6g='[]'


	############################################################################
	# VALIDATE UPTIME
	############################################################################

	case "$uptime" in
		''|*[!0-9-]*)
			uptime=0
			;;
	esac


	############################################################################
	# PUBLIC JSON
	#
	# IMPORTANT:
	# NEVER add username/password/port here.
	############################################################################

	printf '{'

	printf '"section":%s,' \
		"$(json_string "$cfg")"

	printf '"enabled":%s,' \
		"$(json_boolean "$enabled")"

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
# HOST LIST CALLBACK
#
# config_foreach preserves UCI configuration order.
###############################################################################

build_hosts_foreach()
{
	local cfg="$1"
	local item

	apc_debug rpc \
		"status cache host=$cfg"

	item="$(build_one_host "$cfg" 2>/dev/null)"

	[ -n "$item" ] || return 0

	if [ "$BUILD_HOSTS_FIRST" -eq 0 ]; then
		printf ','
	fi

	printf '%s' "$item"

	BUILD_HOSTS_FIRST=0
}


###############################################################################
# BUILD HOST ARRAY
###############################################################################

build_hosts()
{
	BUILD_HOSTS_FIRST=1

	printf '['

	config_load apcontroller

	config_foreach build_hosts_foreach host

	printf ']'
}


###############################################################################
# RPC STATUS
###############################################################################

rpc_status()
{
	apc_debug rpc "status request"

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
		jsonfilter -q -e '@.section' 2>/dev/null
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

	apc_debug rpc \
		"activity section=$section ip=$ipaddr"

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

	apc_debug rpc "scripts request"

	printf '{"scripts":['

	for file in "${SCRIPTFOLDER}"/*; do

		[ -f "$file" ] || continue

		filename="$(basename "$file")"
		description="$filename"
		warn=0

		if grep -q \
			'^# APController-Warn:[[:space:]]*1' \
			"$file" 2>/dev/null
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
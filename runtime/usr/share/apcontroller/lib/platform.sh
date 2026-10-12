#!/bin/sh

#
# APController platform manager
# Path:
#   /usr/share/apcontroller/lib/platform.sh
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"
LIBFOLDER="${BASEFOLDER}/lib"
PLATFORMFOLDER="${BASEFOLDER}/platforms"

. "${LIBFOLDER}/common.sh"
. "${LIBFOLDER}/ssh.sh"
. "${LIBFOLDER}/vendor.sh"


###############################################################################
# PLATFORM LIST
###############################################################################

APC_PLATFORM_LIST="default mikrotik omada openwrt ubiquiti"


###############################################################################
# PLATFORM FILE
###############################################################################

apc_platform_dir()
{
	local platform="$1"

	printf '%s/%s\n' \
		"$PLATFORMFOLDER" \
		"$platform"
}


apc_platform_def()
{
	local platform="$1"

	printf '%s/defplatform.sh\n' \
		"$(apc_platform_dir "$platform")"
}


apc_platform_agent()
{
	local platform="$1"

	printf '%s/agent.sh\n' \
		"$(apc_platform_dir "$platform")"
}


###############################################################################
# LOAD PLATFORM
###############################################################################

apc_platform_load()
{
	local platform="$1"
	local def

	def="$(apc_platform_def "$platform")"

	[ -r "$def" ] || return 1

	#
	# shellcheck source=/dev/null
	#
	. "$def"

	return 0
}


###############################################################################
# REMOTE DETECTION
#
# Each platform's defplatform.sh provides:
#
#   apc_platform_<platform>_detect()
#
# which prints:
#
#   PLATFORM
#
###############################################################################

apc_platform_detect_one()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	local function
	local script
	local result

	apc_platform_load "$platform" || return 1
	if [ "$platform" = omada ]; then
		result="$(apc_platform_omada_detect_local "$host" "$port" "$username" "$password" "$keyfile" "$usekeyfile")" || return 1
		[ "$result" = OMADA ] && { echo omada; return 0; }
		return 1
	fi

	function="apc_platform_${platform}_detect"

	type "$function" >/dev/null 2>&1 || return 1

	script="$("$function")"

	[ -n "$script" ] || return 1

	apc_debug platform \
		"trying platform=$platform host=$host"

	local legacy=0
	[ "$platform" = ubiquiti ] && legacy=1
	result="$(
		printf '%s\n' "$script" |
		APC_SSH_LEGACY="$legacy" apc_ssh_pipe \
			"$host" \
			"$port" \
			"$username" \
			"$password" \
			"$keyfile" \
			"$usekeyfile" \
			"sh -s" \
			2>/dev/null
	)"

	[ -n "$result" ] || return 1

	case "$result" in

		*OPENWRT*)
			[ "$platform" = "openwrt" ] || return 1
			;;

		*UBIQUITI*)
			[ "$platform" = "ubiquiti" ] || return 1
			;;

		*OMADA*)
			[ "$platform" = "omada" ] || return 1
			;;

		*MIKROTIK*)
			[ "$platform" = "mikrotik" ] || return 1
			;;

		*DEFAULT*)
			[ "$platform" = "default" ] || return 1
			;;

		*)
			return 1
			;;

	esac

	printf '%s\n' "$platform"

	return 0
}


###############################################################################
# PLATFORM DETECTION
###############################################################################

apc_platform_detect()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"

	local platform
	local result

	[ -n "$host" ] || return 1
	[ -n "$username" ] || return 1

	for platform in $APC_PLATFORM_LIST; do

		result="$(
			apc_platform_detect_one \
				"$platform" \
				"$host" \
				"$port" \
				"$username" \
				"$password" \
				"$keyfile" \
				"$usekeyfile"
		)"

		if [ -n "$result" ]; then

			apc_debug platform \
				"detected platform=$result host=$host"

			printf '%s\n' "$result"

			return 0
		fi

	done

	apc_debug platform \
		"no platform detected host=$host"

	return 1
}


###############################################################################
# AGENT LOCAL VERSION
###############################################################################

apc_platform_agent_version()
{
	local platform="$1"
	local agent

	agent="$(apc_platform_agent "$platform")"

	[ -r "$agent" ] || return 1

	grep -m1 \
		'^# APController-Agent-Version:' \
		"$agent" 2>/dev/null |
		sed 's/^# APController-Agent-Version:[[:space:]]*//'

	return 0
}


###############################################################################
# REMOTE TEMP DIRECTORY
###############################################################################

apc_platform_remote_dir()
{
	local platform="$1"

	printf '%s\n' \
		"/tmp/apcontroller-${platform}"
}


###############################################################################
# REMOTE AGENT PATH
###############################################################################

apc_platform_agent_remote_path()
{
	local platform="$1"

	printf '%s/agent.sh\n' \
		"$(apc_platform_remote_dir "$platform")"
}


###############################################################################
# REMOTE SCHEMA PATH
###############################################################################

apc_platform_schema_remote_path()
{
    local platform="$1"

    printf '%s/platforms/%s/schema.json\n' \
        "$(apc_platform_remote_dir "$platform")" \
        "$platform"
}




###############################################################################
# CREATE REMOTE TEMP DIRECTORY
###############################################################################

apc_platform_remote_dir_create()
{
    local platform="$1"
    local host="$2"
    local port="$3"
    local username="$4"
    local password="$5"
    local keyfile="$6"
    local usekeyfile="$7"

    local remote_dir
    local platform_dir
    local ret

    remote_dir="$(apc_platform_remote_dir "$platform")"
    platform_dir="${remote_dir}/platforms/${platform}"

    apc_debug platform \
        "creating remote temp directory platform=$platform host=$host dir=$remote_dir"

    apc_ssh_exec \
        "$host" \
        "$port" \
        "$username" \
        "$password" \
        "$keyfile" \
        "$usekeyfile" \
        "mkdir -p '$platform_dir'"

    ret=$?

    if [ "$ret" -ne 0 ]; then

        apc_debug platform \
            "remote temp directory creation failed platform=$platform host=$host"

        return "$ret"
    fi

    return 0
}

###############################################################################
# STANDALONE AGENT VERSION
#
# The remote executable is NOT the original platform agent.sh.
# It is a generated bundle containing:
#
#   common.sh
#   ssh.sh
#   engine.sh
#   platform/agent.sh
#
# Therefore the hash must be calculated from the generated bundle.
###############################################################################

apc_platform_bundle_hash()
{
	local platform="$1"
	local bundle="$2"

	[ -n "$platform" ] || return 1
	[ -f "$bundle" ] || return 1

	apc_local_file_hash "$bundle"
}

###############################################################################
# REMOVE REMOTE TEMP DIRECTORY
#
# IMPORTANT:
# Remote agent and schema are persistent between controller polls.
#
# Do NOT remove them after every execution.
###############################################################################

apc_platform_remote_dir_remove()
{
	local platform="$1"

	#
	# Intentionally do nothing.
	#
	# The remote agent is cached on the AP and is updated only when
	# its content changes.
	#

	apc_debug platform \
		"keeping remote agent platform=$platform"

	return 0
}



###############################################################################
# CHECK REMOTE AGENT
###############################################################################

apc_platform_agent_exists()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	local remote

	remote="$(apc_platform_agent_remote_path "$platform")"

	apc_ssh_file_exists \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"$remote"

	return $?
}


###############################################################################
# BUILD STANDALONE REMOTE AGENT
#
# Creates ONE self-contained shell script from:
#
#   common.sh
#   engine.sh
#   platform agent.sh
#
# The remote host must NOT need:
#
#   /usr/share/apcontroller
#
# and must NOT need:
#
#   common.sh
#   engine.sh
#
# as separate files.
#
# Standalone runtime:
#
#   APC_STANDALONE=1
#
# prevents common.sh from executing controller-side configuration
# initialization.
###############################################################################

apc_platform_build_agent()
{
	local platform="$1"
	local output="$2"

	local localagent
	local common
	local ssh
	local engine
	local platformfolder
	local schema

	[ -n "$platform" ] || return 1
	[ -n "$output" ] || return 1

	localagent="$(apc_platform_agent "$platform")"
	common="${LIBFOLDER}/common.sh"
	ssh="${LIBFOLDER}/ssh.sh"
	engine="${LIBFOLDER}/engine.sh"
	platformfolder="${PLATFORMFOLDER}/${platform}"
	schema="${platformfolder}/schema.json"

	[ -r "$common" ] || return 1
	[ -r "$ssh" ] || return 1
	[ -r "$engine" ] || return 1
	[ -r "$localagent" ] || return 1
	[ -r "$schema" ] || return 1

	{
		printf '%s\n' '#!/bin/sh'
		printf '%s\n' ''
		printf '%s\n' '# APController standalone remote agent'
		printf '%s\n' "# Platform: $platform"
		printf '%s\n' ''
		printf '%s\n' "APC_PLATFORM=\"$platform\""


		############################################################################
		# STANDALONE RUNTIME
		############################################################################

		cat <<EOF
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

APC_STANDALONE=1

BASEFOLDER="/tmp/apcontroller-${platform}"
LIBFOLDER="\$BASEFOLDER/lib"
PLATFORMFOLDER="\$BASEFOLDER/platforms"
BASEPATH="\$BASEFOLDER"

APC_CONFIG_PATH="\$BASEFOLDER"
APC_LOGFILE="\$BASEFOLDER/apcontroller.log"
APC_LOG_STDERR=1
APC_DEBUG=0

mkdir -p "\$BASEPATH" 2>/dev/null
EOF

		printf '%s\n' ''

		############################################################################
		# COMMON
		############################################################################

		printf '%s\n' '# ===== BEGIN common.sh ====='

sed \
    -e '/^[[:space:]]*\.[[:space:]]*.*common\.sh/d' \
    -e '/^[[:space:]]*source[[:space:]]*.*common\.sh/d' \
    "$common"


		printf '%s\n' '# ===== END common.sh ====='
		printf '%s\n' ''

		############################################################################
		# SSH
		############################################################################

		printf '%s\n' '# ===== BEGIN ssh.sh ====='

                sed \
                        -e '/^[[:space:]]*\.[[:space:]].*\(common\|ssh\|engine\)\.sh/d' \
                        -e '/^[[:space:]]*source[[:space:]].*\(common\|ssh\|engine\)\.sh/d' \
                        "$ssh"
			

		printf '%s\n' '# ===== END ssh.sh ====='
		printf '%s\n' ''

		############################################################################
		# ENGINE
		############################################################################

		printf '%s\n' '# ===== BEGIN engine.sh ====='

sed \
    -e '/^[[:space:]]*\.[[:space:]]*.*common\.sh/d' \
    -e '/^[[:space:]]*source[[:space:]]*.*common\.sh/d' \
    -e '/^[[:space:]]*\.[[:space:]]*.*engine\.sh/d' \
    -e '/^[[:space:]]*source[[:space:]]*.*engine\.sh/d' \
    "$engine"


		printf '%s\n' '# ===== END engine.sh ====='
		printf '%s\n' ''

		############################################################################
		# PLATFORM AGENT
		############################################################################

		printf '%s\n' '# ===== BEGIN platform agent.sh ====='

sed \
    -e '/^[[:space:]]*\.[[:space:]]*.*common\.sh/d' \
    -e '/^[[:space:]]*source[[:space:]]*.*common\.sh/d' \
    -e '/^[[:space:]]*\.[[:space:]]*.*engine\.sh/d' \
    -e '/^[[:space:]]*source[[:space:]]*.*engine\.sh/d' \
    "$localagent"



		printf '%s\n' '# ===== END platform agent.sh ====='
		printf '%s\n' ''

	} > "$output" || return 1

###############################################################################
# VALIDATE GENERATED STANDALONE AGENT
###############################################################################

if ! sh -n "$output" 2>/tmp/apcontroller-agent-syntax.$$
then

	apc_debug platform \
		"standalone agent syntax error platform=$platform output=$output"

	cat /tmp/apcontroller-agent-syntax.$$ >&2 2>/dev/null

	rm -f \
		"$output" \
		"/tmp/apcontroller-agent-syntax.$$"

	return 2
fi

rm -f "/tmp/apcontroller-agent-syntax.$$"


if grep -Eq '^[[:space:]]*(\.|source)[[:space:]].*(common|engine|ssh)\.sh' "$output"
then
    apc_debug platform \
        "standalone agent contains external library import output=$output"

    grep -nE '^[[:space:]]*(\.|source)[[:space:]].*(common|engine|ssh)\.sh' \
        "$output" >&2

    rm -f "$output"

    return 1
fi

	chmod 755 "$output" 2>/dev/null || return 1

	return 0
}




###############################################################################
# UPLOAD REMOTE SCHEMA
###############################################################################

apc_platform_schema_upload()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	local localschema
	local remoteschema

	localschema="${PLATFORMFOLDER}/${platform}/schema.json"
	remoteschema="$(apc_platform_schema_remote_path "$platform")"

	[ -r "$localschema" ] || {

		apc_debug platform \
			"schema missing platform=$platform file=$localschema"

		return 1
	}

	apc_debug platform \
		"upload schema platform=$platform host=$host remote=$remoteschema"

	apc_ssh_upload \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"$localschema" \
		"$remoteschema"

	return $?
}

###############################################################################
# UPDATE REMOTE SCHEMA
#
# Upload only when:
#
#   - schema does not exist
#   - schema hash differs
###############################################################################

apc_platform_schema_update()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	local localschema
	local remoteschema
	local localhash
	local remotehash
	local ret

	localschema="${PLATFORMFOLDER}/${platform}/schema.json"
	remoteschema="$(apc_platform_schema_remote_path "$platform")"

	[ -f "$localschema" ] || {

		apc_debug platform \
			"schema missing platform=$platform file=$localschema"

		return 1
	}

	localhash="$(
		apc_local_file_hash "$localschema"
	)"

	[ -n "$localhash" ] || return 1

	remotehash="$(
		apc_ssh_file_hash \
			"$host" \
			"$port" \
			"$username" \
			"$password" \
			"$keyfile" \
			"$usekeyfile" \
			"$remoteschema"
	)"

	if [ -n "$remotehash" ] &&
		[ "$localhash" = "$remotehash" ]
	then

		apc_debug platform \
			"schema current platform=$platform host=$host hash=$localhash"

		return 0
	fi

	apc_debug platform \
		"updating schema platform=$platform host=$host local=$localhash remote=${remotehash:-missing}"

	apc_ssh_upload \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"$localschema" \
		"$remoteschema"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"schema upload failed platform=$platform host=$host ret=$ret"

		return "$ret"
	fi

	apc_debug platform \
		"schema updated platform=$platform host=$host hash=$localhash"

	return 0
}

###############################################################################
# UPDATE STANDALONE AGENT
#
# The remote agent is persistent.
#
# Upload only when:
#
#   - remote agent does not exist
#   - remote agent hash differs
#
# The hash is calculated from the generated standalone bundle.
###############################################################################

apc_platform_agent_update()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"
	local bundle="$8"

	local remoteagent
	local localhash
	local remotehash
	local ret

	[ -n "$platform" ] || return 1
	[ -n "$bundle" ] || return 1
	[ -f "$bundle" ] || return 1

	remoteagent="$(apc_platform_agent_remote_path "$platform")"

	localhash="$(apc_platform_bundle_hash "$platform" "$bundle")"

	[ -n "$localhash" ] || {

		apc_debug platform \
			"cannot calculate bundle hash platform=$platform"

		return 1
	}

	remotehash="$(
		apc_ssh_file_hash \
			"$host" \
			"$port" \
			"$username" \
			"$password" \
			"$keyfile" \
			"$usekeyfile" \
			"$remoteagent"
	)"

	if [ -n "$remotehash" ] &&
		[ "$localhash" = "$remotehash" ]
	then

		apc_debug platform \
			"standalone agent current platform=$platform host=$host hash=$localhash"

		return 0
	fi

	apc_debug platform \
		"updating standalone agent platform=$platform host=$host local=$localhash remote=${remotehash:-missing}"

	apc_ssh_upload \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"$bundle" \
		"$remoteagent"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"standalone agent upload failed platform=$platform host=$host ret=$ret"

		return "$ret"
	fi

	apc_ssh_exec \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"chmod 755 '$remoteagent'"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"standalone agent chmod failed platform=$platform host=$host ret=$ret"

		return "$ret"
	fi

	apc_debug platform \
		"standalone agent updated platform=$platform host=$host hash=$localhash"

	return 0
}


###############################################################################
# EXECUTE AGENT THROUGH SSH
###############################################################################

apc_platform_execute_ssh()
{
	local platform="$1"
	local host="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"
	local operation="$8"
	local output="$9"

	local remoteagent
	local ret

	[ -n "$platform" ] || return 1
	[ -n "$output" ] || return 1

	remoteagent="$(apc_platform_agent_remote_path "$platform")"


	apc_platform_agent_update \
		"$platform" \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile"

	ret=$?

	[ "$ret" -eq 0 ] || return "$ret"


	apc_debug platform \
		"execute agent host=$host platform=$platform operation=$operation"


	apc_ssh_exec \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"'$remoteagent' '$operation'" \
		> "$output" 2>/dev/null

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"agent execution failed host=$host platform=$platform ret=$ret"

		return "$ret"
	fi


	[ -s "$output" ] || {

		apc_debug platform \
			"agent returned empty output host=$host platform=$platform"

		return 1
	}

	return 0
}


###############################################################################
# GENERIC PLATFORM EXECUTE
#
# Strategy:
#
#   1. configured HTTP API
#   2. common HTTP API
#   3. persistent standalone SSH agent
#
# Remote agent/schema are cached.
# They are uploaded only when missing or changed.
###############################################################################

apc_platform_execute()
{
	local platform="$1"
	local ipaddr="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"
	local action="$8"
	local output="$9"
	local api_url="${10}"
	local api_method="${11}"
	local api_token="${12}"

	local platform_dir
	local defplatform
	local agent
	local bundle
	local ret

	[ -n "$platform" ] || return 1
	[ -n "$ipaddr" ] || return 1
	[ -n "$output" ] || return 1

	platform_dir="${BASEFOLDER}/platforms/${platform}"
	if [ "$action" = poll ]; then
		case "$platform" in ubiquiti|omada) apc_vendor_poll "$platform" "$ipaddr" "$port" "$username" "$password" "$keyfile" "$usekeyfile" "$output"; return $?;; esac
	fi

	defplatform="${platform_dir}/defplatform.sh"
	agent="${platform_dir}/agent.sh"

	bundle="/tmp/apcontroller-${platform}-agent.bundle.$$"

	############################################################################
	# PLATFORM DEFINITION
	############################################################################

	if [ -f "$defplatform" ]; then
		. "$defplatform"
	fi

	############################################################################
	# CONFIGURED HTTP API
	############################################################################

	if [ -n "$api_url" ]; then

		apc_debug platform \
			"trying configured HTTP API host=$ipaddr"

		if apc_http_request \
			"$api_url" \
			"$api_method" \
			"$api_token" \
			"$output"
		then

			if apc_validate_host_response "$output"; then

				apc_debug platform \
					"HTTP success host=$ipaddr platform=$platform"

				return 0
			fi

			apc_debug platform \
				"configured HTTP returned invalid JSON host=$ipaddr platform=$platform"
		fi
	fi

	############################################################################
	# DEFAULT HTTP
	############################################################################

	apc_debug platform \
		"trying common HTTP API host=$ipaddr"

	if apc_http_status \
		"$ipaddr" \
		"${API_PORT:-8080}" \
		"$output"
	then

		if apc_validate_host_response "$output"; then

			apc_debug platform \
				"HTTP success host=$ipaddr platform=$platform"

			return 0
		fi

		apc_debug platform \
			"common HTTP returned invalid JSON host=$ipaddr platform=$platform"
	fi

	############################################################################
	# SSH AGENT
	############################################################################

	[ -f "$agent" ] || {

		apc_debug platform \
			"agent missing platform=$platform"

		return 1
	}

	apc_debug platform \
		"HTTP unavailable, using persistent SSH agent host=$ipaddr platform=$platform"

	############################################################################
	# BUILD CURRENT BUNDLE
	############################################################################

	rm -f "$bundle"

	apc_platform_build_agent \
		"$platform" \
		"$bundle"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"agent build failed platform=$platform host=$ipaddr ret=$ret"

		rm -f "$bundle"

		return "$ret"
	fi

	############################################################################
	# CREATE REMOTE DIRECTORY
	#
	# Only creates it if missing.
	############################################################################

	apc_platform_remote_dir_create \
		"$platform" \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		rm -f "$bundle"

		return "$ret"
	fi

	############################################################################
	# UPDATE AGENT ONLY IF CHANGED
	############################################################################

	apc_platform_agent_update \
		"$platform" \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"$bundle"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"agent update failed platform=$platform host=$ipaddr ret=$ret"

		rm -f "$bundle"

		return "$ret"
	fi

	############################################################################
	# UPDATE SCHEMA ONLY IF CHANGED
	############################################################################

	apc_platform_schema_update \
		"$platform" \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile"

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"schema update failed platform=$platform host=$ipaddr ret=$ret"

		rm -f "$bundle"

		return "$ret"
	fi

	############################################################################
	# EXECUTE PERSISTENT AGENT
	############################################################################

	apc_debug platform \
		"executing persistent agent platform=$platform host=$ipaddr action=$action"

	apc_ssh_exec \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"'$(apc_platform_agent_remote_path "$platform")' '$action'" \
		> "$output" 2>/dev/null

	ret=$?

	############################################################################
	# LOCAL BUNDLE CLEANUP ONLY
	############################################################################

	rm -f "$bundle"

	############################################################################
	# EXECUTION ERROR
	############################################################################

	if [ "$ret" -ne 0 ]; then

		apc_debug platform \
			"agent execution failed platform=$platform host=$ipaddr ret=$ret"

		return "$ret"
	fi

	############################################################################
	# EMPTY RESPONSE
	############################################################################

	if [ ! -s "$output" ]; then

		apc_debug platform \
			"agent returned empty output platform=$platform host=$ipaddr"

		return 1
	fi

	############################################################################
	# JSON VALIDATION
	############################################################################

	if ! apc_validate_host_response "$output"; then

		apc_debug platform \
			"agent returned invalid JSON platform=$platform host=$ipaddr"

		apc_debug platform \
			"agent output follows platform=$platform host=$ipaddr"

		cat "$output" >&2 2>/dev/null

		return 1
	fi

	apc_debug platform \
		"agent success platform=$platform host=$ipaddr"

	return 0
}



###############################################################################
# HTTP STATUS
###############################################################################

apc_http_status()
{
	local ipaddr="$1"
	local port="$2"
	local output="$3"

	local url
	local ret

	[ -n "$ipaddr" ] || return 1
	[ -n "$output" ] || return 1

	[ -n "$port" ] || port=8080

	url="http://${ipaddr}:${port}/status"

	apc_debug rpc \
		"http status host=$ipaddr url=$url"

	if command -v curl >/dev/null 2>&1; then

		curl -fsS \
			--connect-timeout 3 \
			--max-time 8 \
			"$url" \
			> "$output" 2>/dev/null

		ret=$?

	elif command -v uclient-fetch >/dev/null 2>&1; then

		uclient-fetch \
			-q \
			-O "$output" \
			"$url"

		ret=$?

	else

		apc_debug rpc \
			"http client unavailable"

		return 1
	fi


	[ "$ret" -eq 0 ] || {

		# rm -f "$output"

		return 1
	}

	[ -s "$output" ] || {

		# rm -f "$output"

		return 1
	}

	return 0
}


###############################################################################
# GENERIC HTTP REQUEST
###############################################################################

apc_http_request()
{
	local url="$1"
	local method="$2"
	local token="$3"
	local output="$4"

	local ret

	[ -n "$url" ] || return 1
	[ -n "$output" ] || return 1

	method="${method:-GET}"


	if command -v curl >/dev/null 2>&1; then

		case "$method" in

			GET|get)

				if [ -n "$token" ]; then

					curl -fsS \
						--connect-timeout 3 \
						--max-time 8 \
						-H "Authorization: Bearer $token" \
						"$url" \
						> "$output" 2>/dev/null

				else

					curl -fsS \
						--connect-timeout 3 \
						--max-time 8 \
						"$url" \
						> "$output" 2>/dev/null

				fi
				;;

			*)

				if [ -n "$token" ]; then

					curl -fsS \
						--connect-timeout 3 \
						--max-time 8 \
						-X "$method" \
						-H "Authorization: Bearer $token" \
						"$url" \
						> "$output" 2>/dev/null

				else

					curl -fsS \
						--connect-timeout 3 \
						--max-time 8 \
						-X "$method" \
						"$url" \
						> "$output" 2>/dev/null

				fi
				;;

		esac

		ret=$?

	else

		return 1
	fi


	[ "$ret" -eq 0 ] || {

		# rm -f "$output"

		return 1
	}

	return 0
}

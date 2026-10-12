#!/bin/sh

#
# APController SSH transport
# Path:
#   /usr/share/apcontroller/lib/ssh.sh
#
# ssh.sh
[ "${APC_SSH_LOADED:-0}" = 1 ] && return 0
APC_SSH_LOADED=1

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"

. "${BASEFOLDER}/lib/common.sh"


###############################################################################
# SSH OPTIONS
###############################################################################

apc_ssh_options()
{
	local port="$1"
	local keyfile="$2"
	local usekeyfile="$3"
	local hostkeys='+ssh-rsa'
	[ "${APC_SSH_LEGACY:-0}" = 1 ] && hostkeys='ssh-rsa'

	[ -n "$port" ] || port=22
	mkdir -p /etc/apcontroller; chmod 700 /etc/apcontroller
	touch /etc/apcontroller/known_hosts; chmod 600 /etc/apcontroller/known_hosts

	printf '%s\n' \
		"-o" "ConnectTimeout=5" \
		"-o" "ServerAliveInterval=5" \
		"-o" "ServerAliveCountMax=2" \
		"-o" "HostKeyAlgorithms=$hostkeys" \
		"-o" "StrictHostKeyChecking=accept-new" \
		"-o" "UserKnownHostsFile=/etc/apcontroller/known_hosts" \
		"-p" "$port"

	if [ "$usekeyfile" = "1" ] && [ -n "$keyfile" ]; then

		printf '%s\n' \
			"-i" "$keyfile"

	fi
}


###############################################################################
# SSH COMMAND
#
# Arguments:
#
#   $1 host
#   $2 port
#   $3 username
#   $4 password
#   $5 keyfile
#   $6 usekeyfile
#   $7 command
#
###############################################################################

apc_ssh_exec()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local command="$7"

	local args
	local ret

	[ -n "$host" ] || return 1
	[ -n "$username" ] || return 1
	[ -n "$command" ] || return 1

	args="$(
		apc_ssh_options \
			"$port" \
			"$keyfile" \
			"$usekeyfile"
	)"

	apc_debug ssh \
		"exec host=$host port=$port user=$username"

	#
	# Password authentication.
	#
	# sshpass is optional. Key authentication does not require it.
	#
	if [ "$usekeyfile" != "1" ] &&
		[ -n "$password" ] &&
		command -v sshpass >/dev/null 2>&1
	then

		SSHPASS="$password" sshpass -e \
			ssh $args \
			"$username@$host" \
			"$command"

		ret=$?

	else

		ssh $args \
			"$username@$host" \
			"$command"

		ret=$?

	fi

	return "$ret"
}


###############################################################################
# SSH PIPE
#
# Executes remote command and feeds stdin.
#
# Arguments:
#
#   $1 host
#   $2 port
#   $3 username
#   $4 password
#   $5 keyfile
#   $6 usekeyfile
#   $7 command
#
###############################################################################

apc_ssh_pipe()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local command="$7"

	local args

	[ -n "$host" ] || return 1
	[ -n "$username" ] || return 1
	[ -n "$command" ] || return 1

	args="$(
		apc_ssh_options \
			"$port" \
			"$keyfile" \
			"$usekeyfile"
	)"

	apc_debug ssh \
		"pipe host=$host port=$port user=$username"

	if [ "$usekeyfile" != "1" ] &&
		[ -n "$password" ] &&
		command -v sshpass >/dev/null 2>&1
	then

		SSHPASS="$password" sshpass -e \
			ssh $args \
			"$username@$host" \
			"$command"

	else

		ssh $args \
			"$username@$host" \
			"$command"

	fi
}


###############################################################################
# REMOTE FILE EXISTS
###############################################################################

apc_ssh_file_exists()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local file="$7"

	apc_ssh_exec \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"[ -f '$file' ]"

	return $?
}


###############################################################################
# REMOTE FILE HASH
###############################################################################

apc_ssh_file_hash()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local file="$7"

	local result

	result="$(
		apc_ssh_exec \
			"$host" \
			"$port" \
			"$username" \
			"$password" \
			"$keyfile" \
			"$usekeyfile" \
			"sha256sum '$file' 2>/dev/null || md5sum '$file' 2>/dev/null"
	)" || return 1

	printf '%s\n' "$result" |
		awk '{print $1}'
}


###############################################################################
# LOCAL FILE HASH
###############################################################################

apc_local_file_hash()
{
	local file="$1"

	[ -f "$file" ] || return 1

	if command -v sha256sum >/dev/null 2>&1; then

		sha256sum "$file" |
			awk '{print $1}'

	elif command -v md5sum >/dev/null 2>&1; then

		md5sum "$file" |
			awk '{print $1}'

	else

		return 1

	fi
}


###############################################################################
# UPLOAD FILE
#
# Uses base64 over SSH.
#
###############################################################################

apc_ssh_upload()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local localfile="$7"
	local remotefile="$8"

	apc_debug ssh \
		"upload host=$ipaddr local=$localfile remote=$remotefile"

	cat "$localfile" |
	apc_ssh_pipe \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"cat > '$remotefile'"

	local ret=$?

	if [ "$ret" -ne 0 ]; then
		apc_debug ssh \
			"pipe upload failed host=$ipaddr ret=$ret"
		return "$ret"
	fi

	apc_ssh_exec \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"chmod 700 '$remotefile'"

	return $?
}



###############################################################################
# REMOVE FILE
###############################################################################

apc_ssh_remove()
{
	local host="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"
	local file="$7"

	apc_ssh_exec \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" \
		"rm -f '$file'"

	return $?
}

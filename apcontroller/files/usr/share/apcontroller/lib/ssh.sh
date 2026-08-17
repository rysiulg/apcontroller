#!/bin/sh

APC_SSH_OPTIONS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

apc_ssh_options()
{
	local platform="$1"

	case "$platform" in
		ubiquiti)
			printf '%s\n' "$APC_SSH_OPTIONS \
				-o HostKeyAlgorithms=+ssh-rsa \
				-o PubkeyAcceptedAlgorithms=+ssh-rsa \
				-o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1"
			;;

		*)
			printf '%s\n' "$APC_SSH_OPTIONS"
			;;
	esac
}


apc_ssh()
{
	local platform="$1"
	local ipaddr="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	shift 7

	local options
	options="$(apc_ssh_options "$platform")"

	if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then
		ssh -q \
			-i "$keyfile" \
			$options \
			-p "$port" \
			"$username@$ipaddr" \
			"$@" 2>/dev/null
	else
		sshpass -p "$password" \
			ssh -q \
			$options \
			-p "$port" \
			"$username@$ipaddr" \
			"$@" 2>/dev/null
	fi
}


apc_scp()
{
	local platform="$1"
	local ipaddr="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"
	local source="$8"
	local destination="$9"

	local options
	options="$(apc_ssh_options "$platform")"

	if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then
		scp -O \
			-i "$keyfile" \
			$options \
			-P "$port" \
			"$source" \
			"$username@$ipaddr:$destination" \
			2>/dev/null
	else
		sshpass -p "$password" \
			scp -O \
			$options \
			-P "$port" \
			"$source" \
			"$username@$ipaddr:$destination" \
			2>/dev/null
	fi
}

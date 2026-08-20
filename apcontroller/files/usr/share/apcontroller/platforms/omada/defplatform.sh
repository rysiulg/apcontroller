#!/bin/sh

###############################################################################
# APController - TP-Link Omada EAP platform
###############################################################################

apc_platform_omada_detect()
{
	#
	# This function is intentionally empty.
	#
	# Omada EAP does NOT expose a normal POSIX shell.
	# Detection therefore happens locally through sexpect.
	#
	return 0
}


###############################################################################
# LOCAL OMADA DETECTION
###############################################################################

apc_platform_omada_detect_local()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local keyfile="$5"
	local usekeyfile="$6"

	local sock
	local ret

	[ -n "$ipaddr" ] || return 1
	[ -n "$username" ] || return 1

	command -v sexpect >/dev/null 2>&1 || {
		apc_debug platform \
			"omada detection unavailable: sexpect missing"
		return 1
	}

	sock="/tmp/apcontroller-detect-$$-$(printf '%s' "$ipaddr" | tr '.' '_').sock"

	rm -f "$sock"

	export SEXPECT_SOCKFILE="$sock"

	apc_debug platform \
		"OMADA interactive detection host=$ipaddr"

	if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then

		sexpect spawn \
			-t 10 \
			-ttl 20 \
			ssh -tt \
				-i "$keyfile" \
				$(apc_ssh_options omada) \
				-p "$port" \
				"$username@$ipaddr"

	else

		sexpect spawn \
			-t 10 \
			-ttl 20 \
			ssh -tt \
				$(apc_ssh_options omada) \
				-o PreferredAuthentications=password \
				-o PubkeyAuthentication=no \
				-p "$port" \
				"$username@$ipaddr"

	fi

	ret=$?

	if [ "$ret" -ne 0 ]; then
		rm -f "$sock"
		return 1
	fi

	#
	# Password.
	#
	if sexpect expect -t 6 -re '[Pp]assword:' >/dev/null 2>&1; then
		sexpect send -cstring "${password}\r"
	fi

	#
	# We specifically want EAP>.
	#
	if sexpect expect -t 8 -re 'EAP>' >/dev/null 2>&1; then

		apc_debug platform \
			"OMADA EAP CLI detected host=$ipaddr prompt=EAP>"

		#
		# Prove privileged CLI exists.
		#
		sexpect send -cstring 'enable\r'

		if sexpect expect -t 8 -re 'EAP#' >/dev/null 2>&1; then

			apc_debug platform \
				"OMADA EAP CLI privileged mode detected host=$ipaddr"

			printf '%s\n' "OMADA"

			sexpect close >/dev/null 2>&1
			rm -f "$sock"

			return 0
		fi
	fi

	apc_debug platform \
		"OMADA detection failed host=$ipaddr"

	sexpect close >/dev/null 2>&1
	rm -f "$sock"

	return 1
}

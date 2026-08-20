#!/bin/sh

#
# APController SSH helpers
# Path: /usr/share/apcontroller/lib/ssh.sh
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

APC_SSH_OPTIONS="${APC_SSH_OPTIONS:-\
-o StrictHostKeyChecking=accept-new \
-o ConnectTimeout=5}"


###############################################################################
# SSH OPTIONS
###############################################################################

apc_ssh_options()
{
	local platform="$1"

	case "$platform" in

		UBIQUITI|ubiquiti)

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


###############################################################################
# SSH
###############################################################################

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

	apc_debug ssh \
		"connect $username@$ipaddr:$port platform=$platform"


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


###############################################################################
# SCP
###############################################################################

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
        local ret

        options="$(apc_ssh_options "$platform")"

        apc_debug ssh \
                "scp $source -> $username@$ipaddr:$destination platform=$platform"

        #
        # First try normal SCP.
        #
        if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then

                scp -O \
                        -i "$keyfile" \
                        $options \
                        -P "$port" \
                        "$source" \
                        "$username@$ipaddr:$destination" \
                        2>/dev/null

                ret=$?

        else

                sshpass -p "$password" \
                        scp -O \
                        $options \
                        -P "$port" \
                        "$source" \
                        "$username@$ipaddr:$destination" \
                        2>/dev/null

                ret=$?

        fi

        #
        # SCP failed.
        #
        # Some old OpenWrt/LEDE/Ubiquiti systems do not provide
        # a usable SCP subsystem. Fall back to plain SSH and stdin.
        #
        if [ "$ret" -ne 0 ]; then

                apc_debug ssh \
                        "scp failed ret=$ret; using ssh-stream fallback host=$ipaddr platform=$platform"

                if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then

                        cat "$source" |
                        ssh -q \
                                -i "$keyfile" \
                                $options \
                                -p "$port" \
                                "$username@$ipaddr" \
                                "cat > '$destination' && chmod 755 '$destination'" \
                                2>/dev/null

                        ret=$?

                else

                        sshpass -p "$password" \
                                sh -c '
                                        cat "$1" |
                                        ssh -q '"$options"' \
                                                -p "$2" \
                                                "$3@$4" \
                                                "cat > '\'''"$destination"'\'\'' && chmod 755 '\'''"$destination"'\'\''" \
                                                2>/dev/null
                                ' sh "$source" "$port" "$username" "$ipaddr"

                        ret=$?

                fi
        fi

        return "$ret"
}

###############################################################################
# OMADA EAP CLI
#
# EAP is NOT a normal shell.
#
# SSH connection gives:
#
#   EAP>
#
# After:
#
#   enable
#
# we get:
#
#   EAP#
#
# All commands therefore have to be executed through a PTY using sexpect.
###############################################################################

###############################################################################
# OMADA EAP CLI
#
# EAP is NOT a normal shell.
#
# SSH connection gives:
#
#   EAP>
#
# After:
#
#   enable
#
# we get:
#
#   EAP#
#
# Communication therefore uses a real PTY through sexpect.
#
# IMPORTANT:
#
#   We DO NOT use:
#
#       sexpect get -expect-buf
#
# because expect consumes the matched data.
#
# Instead the complete PTY output is written to a logfile with:
#
#       sexpect spawn -logfile
#
###############################################################################

apc_eap_cli()
{
	local platform="$1"
	local ipaddr="$2"
	local port="$3"
	local username="$4"
	local password="$5"
	local keyfile="$6"
	local usekeyfile="$7"

	local sock
	local logfile
	local ret
	local sshopts

	[ -n "$ipaddr" ] || return 1
	[ -n "$username" ] || return 1

	command -v sexpect >/dev/null 2>&1 || {
		apc_debug ssh "sexpect not installed"
		return 1
	}

	sock="/tmp/apcontroller-sexpect-$$-${ipaddr//./_}.sock"
	logfile="/tmp/apcontroller-sexpect-$$-${ipaddr//./_}.log"

	rm -f "$sock" "$logfile"

	export SEXPECT_SOCKFILE="$sock"

	sshopts="$(apc_ssh_options "$platform")"

	apc_debug ssh \
		"EAP spawn $username@$ipaddr:$port platform=$platform logfile=$logfile"


	############################################################################
	# SPAWN SSH
	############################################################################

	if [ "$usekeyfile" = "1" ] && [ -e "$keyfile" ]; then

		sexpect spawn \
			-t 15 \
			-ttl 60 \
			-logfile "$logfile" \
			ssh -tt \
				-i "$keyfile" \
				$sshopts \
				-p "$port" \
				"$username@$ipaddr"

	else

		sexpect spawn \
			-t 15 \
			-ttl 60 \
			-logfile "$logfile" \
			ssh -tt \
				$sshopts \
				-o PreferredAuthentications=password \
				-o PubkeyAuthentication=no \
				-p "$port" \
				"$username@$ipaddr"

	fi

	ret=$?

	if [ "$ret" -ne 0 ]; then

		apc_debug ssh \
			"EAP spawn failed host=$ipaddr ret=$ret"

		rm -f "$sock" "$logfile"

		return 1
	fi


	############################################################################
	# PASSWORD
	############################################################################

	if sexpect expect \
		-t 8 \
		-re '[Pp]assword:' \
		>/dev/null 2>&1
	then

		apc_debug ssh \
			"EAP password prompt host=$ipaddr"

		sexpect send \
			-cstring "${password}\r"

	else

		apc_debug ssh \
			"EAP password prompt not seen host=$ipaddr"

	fi


	############################################################################
	# INITIAL PROMPT
	############################################################################

	if ! sexpect expect \
		-t 10 \
		-re 'EAP[>#]' \
		>/dev/null 2>&1
	then

		apc_debug ssh \
			"EAP prompt not detected host=$ipaddr"

		if [ -s "$logfile" ]; then
			apc_debug ssh \
				"EAP login logfile host=$ipaddr: $(head -c 2000 "$logfile")"
		fi

		sexpect close >/dev/null 2>&1

		rm -f "$sock" "$logfile"

		return 1
	fi


	############################################################################
	# ENABLE
	############################################################################

	apc_debug ssh \
		"EAP initial prompt detected host=$ipaddr"

	sexpect send \
		-cstring 'enable\r'


	if ! sexpect expect \
		-t 10 \
		-re 'EAP#' \
		>/dev/null 2>&1
	then

		apc_debug ssh \
			"EAP enable failed host=$ipaddr"

		if [ -s "$logfile" ]; then
			apc_debug ssh \
				"EAP enable logfile host=$ipaddr: $(head -c 2000 "$logfile")"
		fi

		sexpect close >/dev/null 2>&1

		rm -f "$sock" "$logfile"

		return 1
	fi


	apc_debug ssh \
		"EAP privileged CLI ready host=$ipaddr"


	############################################################################
	# COMMANDS
	############################################################################

	while IFS= read -r command; do

		[ -n "$command" ] || continue

		apc_debug ssh \
			"EAP command host=$ipaddr cmd=$command"

		#
		# Send command.
		#
		sexpect send \
			-cstring "${command}\r"


		#
		# Wait for command completion.
		#
		#
		# IMPORTANT:
		#
		# We deliberately DO NOT call:
		#
		#   sexpect get -expect-buf
		#
		# because expect consumes the matching data.
		#
		if ! sexpect expect \
			-t 15 \
			-re 'EAP#' \
			>/dev/null 2>&1
		then

			apc_debug ssh \
				"EAP command timeout host=$ipaddr cmd=$command"

			if [ -s "$logfile" ]; then

				apc_debug ssh \
					"EAP logfile after timeout host=$ipaddr: $(tail -c 3000 "$logfile")"

			fi

			sexpect close >/dev/null 2>&1

			rm -f "$sock" "$logfile"

			return 1
		fi

	done


	############################################################################
	# CLOSE SESSION
	############################################################################

	apc_debug ssh \
		"EAP commands complete host=$ipaddr"


	sexpect close >/dev/null 2>&1

	#
	# Give logfile a moment to flush.
	#
	sleep 1


	############################################################################
	# RETURN LOG
	############################################################################

	if [ -s "$logfile" ]; then

		apc_debug ssh \
			"EAP logfile bytes=$(wc -c < "$logfile") host=$ipaddr"

		#
		# Return complete PTY output.
		#
		cat "$logfile"

	else

		apc_debug ssh \
			"EAP logfile empty host=$ipaddr"

		rm -f "$sock" "$logfile"

		return 1
	fi


	############################################################################
	# CLEANUP
	############################################################################

	rm -f "$sock" "$logfile"

	return 0
}

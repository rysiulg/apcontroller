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

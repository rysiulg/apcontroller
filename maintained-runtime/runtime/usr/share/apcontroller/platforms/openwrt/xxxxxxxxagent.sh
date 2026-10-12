#!/bin/sh

###############################################################################
# APController - TP-Link Omada EAP agent
#
# stdout = JSON ONLY
# stderr/debug = apc_debug() from common.sh
#
# Omada EAP CLI tested against:
#
#   5.2.3 Build 20250709 Rel. 67584 (0001)
#
# Commands collected in ONE SSH session:
#
#   show version
#   show device-id
#   show uptime
#   show process resource
#   show network status
#   show wifi detail
#   show station info
#   show arp table
#   show traffic
###############################################################################

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

BASEFOLDER="${BASEFOLDER:-/usr/share/apcontroller}"
LIBFOLDER="${BASEFOLDER}/lib"

. "${LIBFOLDER}/common.sh"
. "${LIBFOLDER}/ssh.sh"


###############################################################################
# DEBUG
###############################################################################

omada_debug()
{
	apc_debug omada "$*"
}


###############################################################################
# JSON
###############################################################################

json_escape()
{
	printf '%s' "$1" |
	awk '
	BEGIN { ORS="" }
	{
		gsub(/\\/, "\\\\")
		gsub(/"/, "\\\"")
		gsub(/\t/, "\\t")
		gsub(/\r/, "\\r")
		gsub(/\n/, "\\n")
		printf "%s", $0
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


###############################################################################
# TEMP
###############################################################################

TMPDIR="/tmp/apcontroller-omada-$$"

mkdir -p "$TMPDIR" || exit 1


cleanup()
{
	rm -rf "$TMPDIR"
}


trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM


###############################################################################
# EAP COMMANDS
###############################################################################

run_eap_commands()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local usekeyfile="$5"
	local keyfile="$6"

	omada_debug \
		"SSH start host=$ipaddr port=$port user=$username"

	apc_eap_cli \
		"omada" \
		"$ipaddr" \
		"$port" \
		"$username" \
		"$password" \
		"$keyfile" \
		"$usekeyfile" <<'EOF'
show version
show device-id
show uptime
show process resource
show network status
show wifi detail
show station info
show arp table
show traffic
EOF
}


###############################################################################
# RAW DEBUG
###############################################################################

debug_raw()
{
	local raw="$1"
	local bytes
	local preview

	bytes="$(
		printf '%s' "$raw" |
		wc -c 2>/dev/null
	)"

	omada_debug \
		"EAP raw bytes=${bytes:-0}"

	if [ -n "$raw" ]; then

		preview="$(
			printf '%s\n' "$raw" |
			sed \
				-e '/^EAP#/d' \
				-e '/Encryption key:/d' |
			head -c 2000
		)"

		omada_debug \
			"EAP raw preview: $preview"

	else

		omada_debug \
			"EAP raw output EMPTY"

	fi
}


###############################################################################
# SYSTEM
###############################################################################

parse_system()
{
	local data="$1"

	data="$(printf '%s' "$data" | tr -d '\r')"

	SYS_SOFTWARE=""
	SYS_DEVICEID=""
	SYS_HOSTNAME=""
	SYS_MODEL=""
	SYS_MAC=""
	SYS_IPADDR=""

	SYS_SOFTWARE="$(
		printf '%s\n' "$data" |
		awk '
		/^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+Build/ {
			print
			exit
		}'
	)"


	SYS_DEVICEID="$(
		printf '%s\n' "$data" |
		awk '
		/^[0-9A-Fa-f]+$/ &&
		length($0) >= 32 &&
		length($0) <= 64 {
			print
			exit
		}'
	)"


	SYS_IPADDR="$(
		printf '%s\n' "$data" |
		awk '
		/^br0[[:space:]]+Link/ {
			inbr=1
			next
		}

		inbr && /inet addr:/ {
			x=$0
			sub(/^.*inet addr:/, "", x)
			sub(/[[:space:]].*$/, "", x)
			print x
			exit
		}

		/^[^[:space:]]+[[:space:]]+Link/ {
			if ($1 != "br0")
				inbr=0
		}'
	)"


	SYS_MAC="$(
		printf '%s\n' "$data" |
		awk '
		/^br0[[:space:]]+Link/ {
			for (i=1; i<=NF; i++) {
				if ($i == "HWaddr" && i < NF) {
					print $(i+1)
					exit
				}
			}
		}'
	)"


	if [ -z "$SYS_MAC" ]; then

		SYS_MAC="$(
			printf '%s\n' "$data" |
			awk '
			/Access Point:[[:space:]]*[0-9A-Fa-f:.-]+/ {
				x=$0
				sub(/^.*Access Point:[[:space:]]*/, "", x)
				sub(/[[:space:]].*$/, "", x)
				print x
				exit
			}'
		)"

	fi


	omada_debug \
		"system ip=$SYS_IPADDR mac=$SYS_MAC software=$SYS_SOFTWARE deviceid=$SYS_DEVICEID"
}


###############################################################################
# UPTIME / LOAD
###############################################################################

parse_uptime()
{
	local data="$1"

	data="$(printf '%s' "$data" | tr -d '\r')"

	SYS_UPTIME=0
	SYS_LOAD=""


	SYS_UPTIME="$(
		printf '%s\n' "$data" |
		awk '
		/^.*up[[:space:]]+/ {

			line=$0

			if (match(line, /up[[:space:]]+/)) {

				x=substr(line, RSTART + RLENGTH)

				days=0

				if (match(x, /^[0-9]+[[:space:]]+days?/)) {

					d=substr(x, RSTART, RLENGTH)
					sub(/[[:space:]]+days?$/, "", d)

					days=d

					sub(
						/^[0-9]+[[:space:]]+days?[,:]?[[:space:]]*/,
						"",
						x
					)
				}

				hours=0
				minutes=0
				seconds=0

				if (match(x, /^[0-9]+:[0-9]+(:[0-9]+)?/)) {

					t=substr(x, RSTART, RLENGTH)

					n=split(t, p, ":")

					if (n >= 2) {
						hours=p[1]
						minutes=p[2]
					}

					if (n >= 3)
						seconds=p[3]

					print \
						days * 86400 + \
						hours * 3600 + \
						minutes * 60 + \
						seconds

					exit
				}
			}
		}'
	)"


	case "$SYS_UPTIME" in
		''|*[!0-9]*)
			SYS_UPTIME=0
			;;
	esac


	SYS_LOAD="$(
		printf '%s\n' "$data" |
		awk '
		/load average:/ {
			x=$0
			sub(/^.*load average:[[:space:]]*/, "", x)
			gsub(/,/, " ", x)
			print x
			exit
		}'
	)"


	if [ -z "$SYS_LOAD" ]; then

		SYS_LOAD="$(
			printf '%s\n' "$data" |
			awk '
			/^Load average:/ {
				x=$0
				sub(/^.*Load average:[[:space:]]*/, "", x)
				sub(/[[:space:]][0-9]+\/[0-9]+.*$/, "", x)
				gsub(/,/, " ", x)
				print x
				exit
			}'
		)"

	fi


	omada_debug \
		"uptime=$SYS_UPTIME load='$SYS_LOAD'"
}


###############################################################################
# PROCESS / MEMORY
###############################################################################

parse_process_resource()
{
	local data="$1"

	data="$(printf '%s' "$data" | tr -d '\r')"

	SYS_CPU=0

	SYS_CPU_USER=0
	SYS_CPU_SYS=0
	SYS_CPU_NIC=0
	SYS_CPU_IDLE=0
	SYS_CPU_IO=0
	SYS_CPU_IRQ=0
	SYS_CPU_SIRQ=0

	SYS_MEM_USED=0
	SYS_MEM_FREE=0
	SYS_MEM_SHARED=0
	SYS_MEM_BUFFERS=0
	SYS_MEM_CACHED=0


	{
		read SYS_MEM_USED
		read SYS_MEM_FREE
		read SYS_MEM_SHARED
		read SYS_MEM_BUFFERS
		read SYS_MEM_CACHED
	} <<EOF
$(
	printf '%s\n' "$data" |
	awk '
	/^Mem:/ {

		used=0
		free=0
		shrd=0
		buff=0
		cached=0

		for (i=2; i<=NF; i++) {

			x=$i

			if (x ~ /used$/) {
				sub(/K$/, "", x)
				used=x
			}
			else if (x ~ /free$/) {
				sub(/K$/, "", x)
				free=x
			}
			else if (x ~ /shrd$/) {
				sub(/K$/, "", x)
				shrd=x
			}
			else if (x ~ /buff$/) {
				sub(/K$/, "", x)
				buff=x
			}
			else if (x ~ /cached$/) {
				sub(/K$/, "", x)
				cached=x
			}
		}

		print used
		print free
		print shrd
		print buff
		print cached

		exit
	}'
)
EOF


	{
		read SYS_CPU_USER
		read SYS_CPU_SYS
		read SYS_CPU_NIC
		read SYS_CPU_IDLE
		read SYS_CPU_IO
		read SYS_CPU_IRQ
		read SYS_CPU_SIRQ
		read SYS_CPU
	} <<EOF
$(
	printf '%s\n' "$data" |
	awk '
	/^CPU:/ {

		usr=0
		sys=0
		nic=0
		idle=0
		io=0
		irq=0
		sirq=0

		for (i=2; i<=NF; i++) {

			x=$i

			if (x ~ /%$/) {

				value=x
				sub(/%$/, "", value)

				if (i+1 <= NF) {

					field=$(i+1)

					if (field == "usr")
						usr=value
					else if (field == "sys")
						sys=value
					else if (field == "nic")
						nic=value
					else if (field == "idle")
						idle=value
					else if (field == "io")
						io=value
					else if (field == "irq")
						irq=value
					else if (field == "sirq")
						sirq=value
				}
			}
		}

		print usr+0
		print sys+0
		print nic+0
		print idle+0
		print io+0
		print irq+0
		print sirq+0
		print 100-(idle+0)

		exit
	}'
)
EOF


	case "$SYS_CPU" in
		''|*[!0-9.-]*)
			SYS_CPU=0
			;;
	esac

	case "$SYS_CPU_IDLE" in
		''|*[!0-9.-]*)
			SYS_CPU_IDLE=0
			;;
	esac


	omada_debug \
		"cpu=$SYS_CPU idle=$SYS_CPU_IDLE mem_used=${SYS_MEM_USED}K mem_free=${SYS_MEM_FREE}K"
}


###############################################################################
# WIFI / STATION / TRAFFIC
###############################################################################

parse_wifi_data()
{
	local data="$1"

	printf '%s\n' "$data" |
	awk '

	function esc(s)
	{
		gsub(/\r/, "", s)
		gsub(/\\/, "\\\\", s)
		gsub(/"/, "\\\"", s)
		gsub(/\t/, "\\t", s)
		return s
	}


	function macnorm(s)
	{
		gsub(/-/, ":", s)

		if (s ~ /^[0-9A-Fa-f]+[.][0-9A-Fa-f]+[.][0-9A-Fa-f]+$/) {

			gsub(/[.]/, "", s)

			s=substr(s,1,2) ":" \
				substr(s,3,2) ":" \
				substr(s,5,2) ":" \
				substr(s,7,2) ":" \
				substr(s,9,2) ":" \
				substr(s,11,2)
		}

		return tolower(s)
	}


	function ismac(s, x)
	{
		x=s

		gsub(/[:-]/, "", x)
		gsub(/[.]/, "", x)

		if (length(x) != 12)
			return 0

		if (x !~ /^[0-9A-Fa-f]+$/)
			return 0

		return 1
	}


	function num(v)
	{
		if (v == "")
			return 0

		gsub(/[^0-9.-]/, "", v)

		if (v == "")
			return 0

		if (v !~ /^-?[0-9]+([.][0-9]+)?$/)
			return 0

		return v + 0
	}


	function signalnum(v)
	{
		gsub(/[^0-9-]/, "", v)

		if (v == "")
			return 0

		return v + 0
	}


	function seconds(v, x)
	{
		x=v

		if (x == "")
			return 0

		if (x ~ /^[0-9]+s$/) {
			sub(/s$/, "", x)
			return x + 0
		}

		if (x ~ /^[0-9]+m$/) {
			sub(/m$/, "", x)
			return (x + 0) * 60
		}

		if (x ~ /^[0-9]+h$/) {
			sub(/h$/, "", x)
			return (x + 0) * 3600
		}

		if (x ~ /^[0-9]+d$/) {
			sub(/d$/, "", x)
			return (x + 0) * 86400
		}

		if (x ~ /^[0-9]+:[0-9]+(:[0-9]+)?$/) {
			n=split(x,p,":")

			if (n == 2)
				return (p[1]*60)+(p[2]*1)

			if (n == 3)
				return (p[1]*3600)+(p[2]*60)+(p[3]*1)
		}

		return 0
	}


	function freqnorm(f)
	{
		gsub(/[[:space:]]/, "", f)
		gsub(/GHz$/, "", f)

		if (f == "")
			return ""

		if (f ~ /^[0-9]+$/ && length(f) == 4)
			return sprintf("%.3f", f / 1000)

		if (f ~ /^[0-9]+[.][0-9]+$/)
			return sprintf("%.3f", f)

		return f
	}


	function bandfreq(f)
	{
		if (f ~ /^2[.]/)
			return "2g"

		if (f ~ /^5[.]/)
			return "5g"

		if (f ~ /^6[.]/)
			return "6g"

		return "unknown"
	}


	function wifigen(s)
	{
		if (s ~ /802[.]11be/)
			return 7

		if (s ~ /802[.]11ax/)
			return 6

		if (s ~ /802[.]11ac/)
			return 5

		if (s ~ /802[.]11ng/)
			return 4

		if (s ~ /802[.]11n/)
			return 4

		if (s ~ /802[.]11g/)
			return 3

		if (s ~ /802[.]11a/)
			return 3

		if (s ~ /802[.]11b/)
			return 2

		return 0
	}


	function get_iface(line, x)
	{
		x=line

		sub(/^[[:space:]]*/, "", x)

		if (x !~ /^ath[0-9]+([[:space:]:]|$)/)
			return ""

		sub(/[:[:space:]].*$/, "", x)

		if (x ~ /^ath[0-9]+$/)
			return x

		return ""
	}


	function add_radio(iface)
	{
		if (iface == "")
			return

		if (!radio_seen[iface]) {

			radio_count++

			radio_list[radio_count]=iface
			radio_seen[iface]=1

			radio_ssid[iface]=""
			radio_freq[iface]=""
			radio_band[iface]="unknown"
			radio_bssid[iface]=""
			radio_channel[iface]=0
			radio_wifi[iface]=0
		}
	}


	{
		line=$0


		if (line ~ /show[[:space:]]+wifi[[:space:]]+detail/) {

			section="wifi"
			current_radio=""

			next
		}


		if (line ~ /show[[:space:]]+station[[:space:]]+info/) {

			section="station"
			current_radio=""

			next
		}


		if (line ~ /show[[:space:]]+traffic/) {

			section="traffic"
			current_radio=""

			next
		}


		if (line ~ /(^|[[:space:]])show[[:space:]]+/) {

			section=""
			current_radio=""

			next
		}


		############################################################################
		# WIFI
		############################################################################

		if (section == "wifi") {

			iface=get_iface(line)


			if (iface != "" && line ~ /IEEE[[:space:]]+802[.]11/) {

				add_radio(iface)

				current_radio=iface

				radio_wifi[iface]=wifigen(line)


				if (match(line, /ESSID:"[^"]*"/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^ESSID:"/, "", x)
					sub(/"$/, "", x)

					radio_ssid[iface]=x
				}


				if (match(line, /Frequency:[[:space:]]*[0-9.]+([[:space:]]*GHz)?/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Frequency:[[:space:]]*/, "", x)

					radio_freq[iface]=freqnorm(x)
					radio_band[iface]=bandfreq(radio_freq[iface])
				}


				if (match(line, /Access Point:[[:space:]]*[0-9A-Fa-f:.-]+/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Access Point:[[:space:]]*/, "", x)

					radio_bssid[iface]=macnorm(x)
				}


				if (match(line, /Channel:[[:space:]]*[0-9]+/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Channel:[[:space:]]*/, "", x)

					radio_channel[iface]=num(x)
				}

				next
			}


			if (current_radio != "") {

				if (match(line, /ESSID:"[^"]*"/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^ESSID:"/, "", x)
					sub(/"$/, "", x)

					radio_ssid[current_radio]=x
				}


				if (match(line, /Frequency:[[:space:]]*[0-9.]+([[:space:]]*GHz)?/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Frequency:[[:space:]]*/, "", x)

					radio_freq[current_radio]=freqnorm(x)
					radio_band[current_radio]=bandfreq(radio_freq[current_radio])
				}


				if (match(line, /Channel:[[:space:]]*[0-9]+/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Channel:[[:space:]]*/, "", x)

					radio_channel[current_radio]=num(x)
				}


				if (match(line, /Access Point:[[:space:]]*[0-9A-Fa-f:.-]+/)) {

					x=substr(line, RSTART, RLENGTH)

					sub(/^Access Point:[[:space:]]*/, "", x)

					radio_bssid[current_radio]=macnorm(x)
				}
			}

			next
		}


		############################################################################
		# STATION
		############################################################################

		if (section == "station") {

			siface=""
			smac=""
			smacpos=0


			for (j=1; j<=NF; j++) {

				if ($j ~ /^ath[0-9]+$/) {

					siface=$j

					break
				}
			}


			for (j=1; j<=NF; j++) {

				if (ismac($j)) {

					smac=$j
					smacpos=j

					break
				}
			}


			if (siface != "" &&
			    smac != "" &&
			    radio_seen[siface]) {

				smac=macnorm(smac)

				client_key=siface "|" smac


				if (!client_seen[client_key]) {

					client_seen[client_key]=1

					station_count++

					station_iface[station_count]=siface
					station_mac[station_count]=smac

					station_channel[station_count]=radio_channel[siface]

					station_tx[station_count]=""
					station_rx[station_count]=""
					station_signal[station_count]=0
					station_connected[station_count]=0
					station_idle[station_count]=0


					if (smacpos > 1 &&
					    $(smacpos-1) ~ /^[0-9]+$/) {

						station_channel[station_count]= \
							$(smacpos-1)
					}


					if (smacpos+1 <= NF)
						station_tx[station_count]=$(smacpos+1)


					if (smacpos+2 <= NF)
						station_rx[station_count]=$(smacpos+2)


					if (smacpos+3 <= NF)
						station_signal[station_count]=$(smacpos+3)


					if (smacpos+4 <= NF)
						station_connected[station_count]=$(smacpos+4)


					if (smacpos+5 <= NF)
						station_idle[station_count]=$(smacpos+5)
				}
			}

			next
		}


		############################################################################
		# TRAFFIC
		############################################################################

		if (section == "traffic") {

			if ($1 ~ /^ath[0-9]+:$/) {

				tiface=$1
				sub(/:$/, "", tiface)

				if (radio_seen[tiface]) {

					traffic_rx_bytes[tiface]=$2
					traffic_rx_packets[tiface]=$3
					traffic_rx_errors[tiface]=$4
					traffic_rx_drop[tiface]=$5

					traffic_tx_bytes[tiface]=$10
					traffic_tx_packets[tiface]=$11
					traffic_tx_errors[tiface]=$12
					traffic_tx_drop[tiface]=$13
				}
			}

			next
		}
	}


	############################################################################
	# OUTPUT
	############################################################################

	END {

		printf "{"


		printf "\"wifi\":["

		first=1

		for (i=1; i<=radio_count; i++) {

			iface=radio_list[i]

			if (!first)
				printf ","

			first=0


			b=radio_band[iface]

			if (b == "" || b == "unknown")
				b=bandfreq(radio_freq[iface])


			printf "{"

			printf "\"ifname\":\"%s\",", esc(iface)
			printf "\"ssid\":\"%s\",", esc(radio_ssid[iface])
			printf "\"frequency\":\"%s\",", esc(radio_freq[iface])
			printf "\"band\":\"%s\",", esc(b)
			printf "\"bssid\":\"%s\",", esc(radio_bssid[iface])
			printf "\"channel\":%s,", num(radio_channel[iface])
			printf "\"wifi\":%s,", num(radio_wifi[iface])

			printf "\"rx_bytes\":%s,", num(traffic_rx_bytes[iface])
			printf "\"tx_bytes\":%s,", num(traffic_tx_bytes[iface])
			printf "\"rx_packets\":%s,", num(traffic_rx_packets[iface])
			printf "\"tx_packets\":%s,", num(traffic_tx_packets[iface])
			printf "\"rx_errors\":%s,", num(traffic_rx_errors[iface])
			printf "\"tx_errors\":%s,", num(traffic_tx_errors[iface])
			printf "\"rx_drop\":%s,", num(traffic_rx_drop[iface])
			printf "\"tx_drop\":%s", num(traffic_tx_drop[iface])

			printf "}"
		}

		printf "],"


		printf "\"clients\":["

		first=1

		for (i=1; i<=station_count; i++) {

			iface=station_iface[i]
			mac=station_mac[i]
			ch=station_channel[i]

			if (ch == "" || ch == 0)
				ch=radio_channel[iface]


			b=radio_band[iface]

			if (b == "" || b == "unknown")
				b=bandfreq(radio_freq[iface])


			if (!first)
				printf ","

			first=0


			printf "{"

			printf "\"ap\":\"%s\",", esc(iface)
			printf "\"mac\":\"%s\",", esc(mac)

			printf "\"ipaddr\":\"\","
			printf "\"name\":\"\","
			printf "\"hostname\":\"\","

			printf "\"channel\":\"%s\",", esc(ch)
			printf "\"txrate\":\"%s\",", esc(station_tx[i])
			printf "\"rxrate\":\"%s\",", esc(station_rx[i])

			printf "\"signal\":%s,", signalnum(station_signal[i])

			printf "\"connected\":%s,", \
				seconds(station_connected[i])

			printf "\"lastcommunication\":%s,", \
				seconds(station_idle[i])

			printf "\"idle\":%s,", \
				seconds(station_idle[i])

			printf "\"band\":\"%s\",", esc(b)

			printf "\"ssid\":\"%s\",", \
				esc(radio_ssid[iface])

			printf "\"bssid\":\"%s\",", \
				esc(radio_bssid[iface])

			printf "\"interface\":\"%s\",", \
				esc(iface)

			printf "\"rx\":0,"
			printf "\"tx\":0,"
			printf "\"rx_bytes\":0,"
			printf "\"tx_bytes\":0,"

			printf "\"wifi\":%s", \
				num(radio_wifi[iface])

			printf "}"
		}

		printf "],"


		############################################################################
		# CHANNELS
		############################################################################

		c2=""
		c5=""
		c6=""


		for (i=1; i<=radio_count; i++) {

			iface=radio_list[i]
			ch=radio_channel[iface]

			if (ch == "" || ch == 0)
				continue

			b=radio_band[iface]

			if (b == "2g") {

				if (c2 == "")
					c2=ch
				else if (("," c2 ",") !~ ("," ch ","))
					c2=c2 "," ch

			}
			else if (b == "5g") {

				if (c5 == "")
					c5=ch
				else if (("," c5 ",") !~ ("," ch ","))
					c5=c5 "," ch

			}
			else if (b == "6g") {

				if (c6 == "")
					c6=ch
				else if (("," c6 ",") !~ ("," ch ","))
					c6=c6 "," ch
			}
		}


		printf "\"channels2g\":\"%s\",", esc(c2)
		printf "\"channels5g\":\"%s\",", esc(c5)
		printf "\"channels6g\":\"%s\"", esc(c6)

		printf "}"
	}'
}


###############################################################################
# ARP
###############################################################################

parse_arp()
{
	local data="$1"

	ARP_COUNT="$(
		printf '%s\n' "$data" |
		awk '
		/^[?].*\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\).*at[[:space:]]+[0-9A-Fa-f:-]+/ {
			count++
		}
		END {
			print count+0
		}'
	)"

	omada_debug \
		"ARP entries=$ARP_COUNT"
}


###############################################################################
# LAST CONTACT
###############################################################################

get_lastcontact()
{
	local value

	value="$(date +%s 2>/dev/null)"

	case "$value" in
		''|*[!0-9]*)
			printf '0'
			;;
		*)
			printf '%s' "$value"
			;;
	esac
}


###############################################################################
# JSON ARRAY EXTRACTION
#
# parse_wifi_data() returns ONE JSON OBJECT:
#
# {
#   "wifi":[...],
#   "clients":[...],
#   "channels2g":"...",
#   "channels5g":"...",
#   "channels6g":"..."
# }
#
# Do not use greedy ".*" extraction here.  BusyBox/legacy awk implementations
# differ and greedy matching can consume the wrong part of the object.
###############################################################################

extract_wifi_array()
{
	local data="$1"

	printf '%s\n' "$data" |
	awk '
	{
		x=$0

		p=index(x, "\"wifi\":[")
		if (!p)
			exit

		x=substr(x, p + 8)

		depth=0
		in_string=0
		escape=0
		start=1

		for (i=1; i<=length(x); i++) {

			c=substr(x,i,1)

			if (in_string) {

				if (escape) {
					escape=0
					continue
				}

				if (c == "\\") {
					escape=1
					continue
				}

				if (c == "\"")
					in_string=0

				continue
			}

			if (c == "\"") {
				in_string=1
				continue
			}

			if (c == "[") {
				depth++
			}
			else if (c == "]") {

				depth--

				if (depth == 0) {
					print substr(x,start,i)
					exit
				}
			}
		}
	}'
}


extract_clients_array()
{
	local data="$1"

	printf '%s\n' "$data" |
	awk '
	{
		x=$0

		p=index(x, "\"clients\":[")
		if (!p)
			exit

		x=substr(x, p + 11)

		depth=0
		in_string=0
		escape=0
		start=1

		for (i=1; i<=length(x); i++) {

			c=substr(x,i,1)

			if (in_string) {

				if (escape) {
					escape=0
					continue
				}

				if (c == "\\") {
					escape=1
					continue
				}

				if (c == "\"")
					in_string=0

				continue
			}

			if (c == "\"") {
				in_string=1
				continue
			}

			if (c == "[") {
				depth++
			}
			else if (c == "]") {

				depth--

				if (depth == 0) {
					print substr(x,start,i)
					exit
				}
			}
		}
	}'
}


extract_json_string()
{
	local data="$1"
	local key="$2"

	printf '%s\n' "$data" |
	awk -v key="$key" '
	{
		x=$0
		target="\"" key "\":\""

		p=index(x,target)

		if (!p)
			exit

		x=substr(x,p+length(target))

		result=""

		escaped=0

		for (i=1; i<=length(x); i++) {

			c=substr(x,i,1)

			if (escaped) {
				result=result "\\" c
				escaped=0
				continue
			}

			if (c == "\\") {
				escaped=1
				continue
			}

			if (c == "\"") {
				print result
				exit
			}

			result=result c
		}
	}'
}


###############################################################################
# FILTER CLIENT ARRAY BY BAND
###############################################################################

filter_clients_band()
{
	local clients="$1"
	local wanted="$2"

	printf '%s\n' "$clients" |
	awk -v wanted="$wanted" '
	{
		line=$0

		first=1

		while (match(line, /\{[^{}]*\}/)) {

			obj=substr(line,RSTART,RLENGTH)

			if (obj ~ ("\"band\":\"" wanted "\"")) {

				if (!first)
					printf ","

				printf "%s", obj

				first=0
			}

			line=substr(line,RSTART+RLENGTH)
		}

		printf "\n"
	}'
}


###############################################################################
# POLL
###############################################################################

poll()
{
	local ipaddr="$1"
	local port="$2"
	local username="$3"
	local password="$4"
	local usekeyfile="$5"
	local keyfile="$6"

	local raw
	local parsed
	local wifi
	local clients
	local clients2g
	local clients5g
	local clients6g
	local lastcontact

	local channels2g
	local channels5g
	local channels6g


	############################################################################
	# ARGUMENTS
	############################################################################

if [ "$#" -lt 6 ]; then
    omada_debug "poll: invalid arguments count=$#"
    return 9
fi


	if [ -z "$ipaddr" ]; then
		omada_debug "poll: missing ipaddr"
		return 1
	fi


	if [ -z "$username" ]; then
		omada_debug "poll: missing username"
		return 1
	fi


	omada_debug \
		"poll start host=$ipaddr port=$port user=$username usekeyfile=$usekeyfile"


	############################################################################
	# ONE SSH SESSION
	############################################################################

	raw="$(
		run_eap_commands \
			"$ipaddr" \
			"$port" \
			"$username" \
			"$password" \
			"$usekeyfile" \
			"$keyfile"
	)"


	if [ -z "$raw" ]; then

		omada_debug \
			"poll failed: EAP returned EMPTY output host=$ipaddr"

		return 1
	fi


	printf '%s\n' "$raw" > "$TMPDIR/raw"

	debug_raw "$raw"


	############################################################################
	# SYSTEM
	############################################################################

	parse_system "$raw"


	if [ -z "$SYS_MAC" ]; then

		omada_debug \
			"poll failed: no MAC detected host=$ipaddr"

		return 1
	fi


	############################################################################
	# UPTIME
	############################################################################

	parse_uptime "$raw"


	############################################################################
	# CPU / MEMORY
	############################################################################

	parse_process_resource "$raw"


	############################################################################
	# ARP
	############################################################################

	parse_arp "$raw"


	############################################################################
	# WIFI / CLIENTS / TRAFFIC
	############################################################################

	parsed="$(
		parse_wifi_data "$raw"
	)"


	if [ -z "$parsed" ]; then

		omada_debug \
			"poll failed: Wi-Fi parser returned EMPTY output"

		return 1
	fi


	printf '%s\n' "$parsed" > "$TMPDIR/parsed.json"


	############################################################################
	# EXTRACT JSON ARRAYS
	############################################################################

	wifi="$(
		extract_wifi_array "$parsed"
	)"


	clients="$(
		extract_clients_array "$parsed"
	)"


	############################################################################
	# EXTRACT CHANNEL LISTS
	############################################################################

	channels2g="$(
		extract_json_string "$parsed" "channels2g"
	)"


	channels5g="$(
		extract_json_string "$parsed" "channels5g"
	)"


	channels6g="$(
		extract_json_string "$parsed" "channels6g"
	)"


	#
	# The parser itself always produces arrays.  These fallbacks protect the
	# final JSON if a legacy awk implementation returns an empty result.
	#
	case "$wifi" in
		\[*\])
			;;
		*)
			wifi='[]'
			;;
	esac


	case "$clients" in
		\[*\])
			;;
		*)
			clients='[]'
			;;
	esac


	############################################################################
	# CLIENT BAND LISTS
	############################################################################

	clients2g="$(
		filter_clients_band "$clients" "2g"
	)"


	clients5g="$(
		filter_clients_band "$clients" "5g"
	)"


	clients6g="$(
		filter_clients_band "$clients" "6g"
	)"


	if [ -n "$clients2g" ]; then
		clients2g="[$clients2g]"
	else
		clients2g='[]'
	fi


	if [ -n "$clients5g" ]; then
		clients5g="[$clients5g]"
	else
		clients5g='[]'
	fi


	if [ -n "$clients6g" ]; then
		clients6g="[$clients6g]"
	else
		clients6g='[]'
	fi


	############################################################################
	# LAST CONTACT
	############################################################################

	lastcontact="$(get_lastcontact)"


	############################################################################
	# DEBUG
	############################################################################

	omada_debug "wifi=$wifi"
	omada_debug "clients total parser=$clients"
	omada_debug "clients2g=$clients2g"
	omada_debug "clients5g=$clients5g"
	omada_debug "clients6g=$clients6g"

	omada_debug \
		"channels 2g='$channels2g' 5g='$channels5g' 6g='$channels6g'"


	############################################################################
	# FINAL JSON
	############################################################################

	printf '{'

	printf '"type":"openwrt",'
	printf '"platform":"omada",'

	printf '"ipaddr":%s,' \
		"$(json_string "$SYS_IPADDR")"

	printf '"mac":%s,' \
		"$(json_string "$SYS_MAC")"

	printf '"hostname":%s,' \
		"$(json_string "$SYS_HOSTNAME")"

	printf '"model":%s,' \
		"$(json_string "$SYS_MODEL")"

	printf '"deviceid":%s,' \
		"$(json_string "$SYS_DEVICEID")"

	printf '"software":%s,' \
		"$(json_string "$SYS_SOFTWARE")"

	printf '"lastcontact":%s,' \
		"$(json_number "$lastcontact")"

	printf '"uptime":%s,' \
		"$(json_number "$SYS_UPTIME")"

	printf '"load":%s,' \
		"$(json_string "$SYS_LOAD")"

	printf '"cpu":%s,' \
		"$(json_number "$SYS_CPU")"

	printf '"cpu_user":%s,' \
		"$(json_number "$SYS_CPU_USER")"

	printf '"cpu_sys":%s,' \
		"$(json_number "$SYS_CPU_SYS")"

	printf '"cpu_idle":%s,' \
		"$(json_number "$SYS_CPU_IDLE")"

	printf '"cpu_sirq":%s,' \
		"$(json_number "$SYS_CPU_SIRQ")"

	printf '"memory_used":%s,' \
		"$(json_number "$SYS_MEM_USED")"

	printf '"memory_free":%s,' \
		"$(json_number "$SYS_MEM_FREE")"

	printf '"memory_shared":%s,' \
		"$(json_number "$SYS_MEM_SHARED")"

	printf '"memory_buffers":%s,' \
		"$(json_number "$SYS_MEM_BUFFERS")"

	printf '"memory_cached":%s,' \
		"$(json_number "$SYS_MEM_CACHED")"

	printf '"wifi":%s,' \
		"$wifi"

	printf '"clients":%s,' \
		"$clients"

	printf '"clientslist2g":%s,' \
		"$clients2g"

	printf '"clientslist5g":%s,' \
		"$clients5g"

	printf '"clientslist6g":%s,' \
		"$clients6g"

	printf '"channels2g":%s,' \
		"$(json_string "$channels2g")"

	printf '"channels5g":%s,' \
		"$(json_string "$channels5g")"

	printf '"channels6g":%s' \
		"$(json_string "$channels6g")"

	printf '}\n'


	############################################################################
	# SUCCESS
	############################################################################

	omada_debug \
		"poll success host=$ipaddr mac=$SYS_MAC uptime=$SYS_UPTIME"

	return 0
}


###############################################################################
# MAIN
###############################################################################

case "$1" in

	poll)

		shift

		poll "$@"

		exit $?
		;;

	*)

		echo \
			"usage: $0 poll <ip> <port> <username> <password> <usekeyfile> <keyfile>" \
			>&2

		exit 1
		;;

esac
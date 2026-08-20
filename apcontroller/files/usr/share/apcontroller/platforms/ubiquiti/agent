#!/bin/sh
#
# APController - UniFi Legacy UAP agent
#
# Target:
#   Ubiquiti / UniFi legacy UAP
#   U2Lv2 / U2O / UAP / UAP-LR etc.
#   firmware 3.x
#
# stdout = JSON ONLY
# stderr = never used for agent data
# debug = /var/log/apcontroller.log
#
# Source:
#   mca-dump
#
# IMPORTANT:
#   Active channels come from vap_table.
#   radio_table.scan_table is NOT used for active channel.
#

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

###############################################################################
# CONFIG
###############################################################################

APCONTROLLER_DEBUG="@DEBUG@"

case "$APCONTROLLER_DEBUG" in
	1|true|yes|on)
		APC_DEBUG=1
		;;
	*)
		APC_DEBUG=0
		;;
esac

APC_LOGFILE="/var/log/apcontroller.log"

###############################################################################
# DEBUG
###############################################################################

agent_debug()
{
	[ "$APC_DEBUG" = "1" ] || return 0

	printf '[%s][unifi-agent] %s\n' \
		"$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" \
		"$*" >> "$APC_LOGFILE" 2>/dev/null
}

###############################################################################
# TEMP
###############################################################################

TMPBASE="/tmp/apcontroller-unifi.$$"

DUMPFILE="$TMPBASE.dump"
NORMALIZED="$TMPBASE.normalized"
VAPFILE="$TMPBASE.vaps"
CLIENTFILE="$TMPBASE.clients"

cleanup()
{
	rm -f \
		"$DUMPFILE" \
		"$NORMALIZED" \
		"$VAPFILE" \
		"$CLIENTFILE" \
		"$TMPBASE."*

	agent_debug "CLEANUP"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

: > "$DUMPFILE"
: > "$VAPFILE"
: > "$CLIENTFILE"

###############################################################################
# JSON HELPERS
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

jstr()
{
	printf '"%s"' "$(json_escape "$1")"
}

jnum()
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
# GET JSON STRING
###############################################################################

json_get_string()
{
	KEY="$1"

	awk -v wanted="$KEY" '
	BEGIN {
		RS=""
	}

	{
		s=$0

		pat="\"" wanted "\"[[:space:]]*:[[:space:]]*\""

		if (!match(s,pat))
			exit

		x=substr(s,RSTART+RLENGTH)

		out=""
		esc=0

		for (i=1;i<=length(x);i++) {

			c=substr(x,i,1)

			if (esc) {
				if (c=="n")
					out=out "\n"
				else if (c=="r")
					out=out "\r"
				else if (c=="t")
					out=out "\t"
				else
					out=out c

				esc=0
				continue
			}

			if (c=="\\") {
				esc=1
				continue
			}

			if (c=="\"")
				break

			out=out c
		}

		print out
		exit
	}
	' "$NORMALIZED"
}

###############################################################################
# GET JSON NUMBER
###############################################################################

json_get_number()
{
	KEY="$1"

	awk -v wanted="$KEY" '
	BEGIN {
		RS=""
	}

	{
		s=$0

		pat="\"" wanted "\"[[:space:]]*:[[:space:]]*-?[0-9]+"

		if (!match(s,pat))
			exit

		x=substr(s,RSTART,RLENGTH)

		sub(/^.*:[[:space:]]*/, "", x)

		print x
		exit
	}
	' "$NORMALIZED"
}

###############################################################################
# GET FIELD FROM OBJECT
###############################################################################

object_get()
{
	OBJECT="$1"
	KEY="$2"

	printf '%s' "$OBJECT" |
	awk -v wanted="$KEY" '
	BEGIN {
		RS=""
	}

	{
		s=$0

		#
		# String
		#
		pat="\"" wanted "\"[[:space:]]*:[[:space:]]*\""

		if (match(s,pat)) {

			x=substr(s,RSTART+RLENGTH)

			out=""
			esc=0

			for (i=1;i<=length(x);i++) {

				c=substr(x,i,1)

				if (esc) {
					if (c=="n")
						out=out "\n"
					else if (c=="r")
						out=out "\r"
					else if (c=="t")
						out=out "\t"
					else
						out=out c

					esc=0
					continue
				}

				if (c=="\\") {
					esc=1
					continue
				}

				if (c=="\"")
					break

				out=out c
			}

			print out
			exit
		}

		#
		# Number / boolean
		#
		pat="\"" wanted "\"[[:space:]]*:[[:space:]]*-?[0-9]+"

		if (match(s,pat)) {

			x=substr(s,RSTART,RLENGTH)

			sub(/^.*:[[:space:]]*/, "", x)

			print x
			exit
		}

		pat="\"" wanted "\"[[:space:]]*:[[:space:]]*(true|false)"

		if (match(s,pat)) {

			x=substr(s,RSTART,RLENGTH)

			sub(/^.*:[[:space:]]*/, "", x)

			print x
			exit
		}
	}
	'
}

###############################################################################
# RUN MCA-DUMP
###############################################################################

agent_debug "START pid=$$"

if ! command -v mca-dump >/dev/null 2>&1; then

	agent_debug "ERROR mca-dump not found"

	printf '%s\n' \
		'{"type":"unifi","platform":"unifi","status":"error","error":"mca-dump not found","wifi":[],"clients":[],"clientslist":[],"clientslist2g":[],"clientslist5g":[],"clientslist6g":[],"channel2g":0,"channel5g":0,"channel6g":0}'

	exit 0
fi

mca-dump > "$DUMPFILE" 2>/dev/null

DUMP_SIZE="$(wc -c < "$DUMPFILE" 2>/dev/null)"

case "$DUMP_SIZE" in
	''|*[!0-9]*)
		DUMP_SIZE=0
		;;
esac

if [ "$DUMP_SIZE" -le 0 ]; then

	agent_debug "ERROR empty mca-dump"

	printf '%s\n' \
		'{"type":"unifi","platform":"unifi","status":"error","error":"empty mca-dump","wifi":[],"clients":[],"clientslist":[],"clientslist2g":[],"clientslist5g":[],"clientslist6g":[],"channel2g":0,"channel5g":0,"channel6g":0}'

	exit 0
fi

agent_debug "mca-dump bytes=$DUMP_SIZE"

###############################################################################
# NORMALIZE
###############################################################################

tr -d '\r\n' < "$DUMPFILE" > "$NORMALIZED"

###############################################################################
# BASIC AP DATA
###############################################################################

HOSTNAME_VAL="$(json_get_string hostname)"

if [ -z "$HOSTNAME_VAL" ]; then
	HOSTNAME_VAL="$(cat /proc/sys/kernel/hostname 2>/dev/null)"
fi

if [ -z "$HOSTNAME_VAL" ]; then
	HOSTNAME_VAL="$(hostname 2>/dev/null)"
fi

IPADDR="$(json_get_string ip)"
MAC="$(json_get_string mac)"

MODEL="$(json_get_string model)"

if [ -z "$MODEL" ]; then
	MODEL="$(json_get_string model_display)"
fi

SOFTWARE="$(json_get_string version)"

if [ -z "$SOFTWARE" ]; then
	SOFTWARE="$(json_get_string sw_version)"
fi

if [ -z "$SOFTWARE" ]; then
	SOFTWARE="$(json_get_string firmware)"
fi

UPTIME="$(json_get_number uptime)"

case "$UPTIME" in
	''|*[!0-9]*)
		UPTIME=0
		;;
esac

LASTCONTACT="$(json_get_number time)"

case "$LASTCONTACT" in
	''|*[!0-9]*)
		LASTCONTACT="$(date +%s 2>/dev/null)"
		;;
esac

case "$LASTCONTACT" in
	''|*[!0-9]*)
		LASTCONTACT=0
		;;
esac

###############################################################################
# LOAD
###############################################################################

LOAD=""

if [ -r /proc/loadavg ]; then
	LOAD="$(
		awk '
		{
			printf "%s %s %s", $1,$2,$3
			exit
		}' /proc/loadavg 2>/dev/null
	)"
fi

###############################################################################
# STATUS
###############################################################################

STATE_NUM="$(json_get_number state)"

case "$STATE_NUM" in
	2)
		STATUS="pending"
		;;
	*)
		STATUS="active"
		;;
esac

###############################################################################
# EXTRACT VAP OBJECTS
#
# This is the important part.
#
# We parse:
#
#   vap_table:[ {... sta_table:[{...}]} , {...} ]
#
# by counting braces.
#
# We DO NOT use:
#
#   tr '{}'
#
# because that destroys the JSON objects.
###############################################################################

extract_vaps()
{
	awk '
	BEGIN {
		RS=""
	}

	{
		s=$0

		#
		# Find vap_table.
		#
		pat="\"vap_table\"[[:space:]]*:[[:space:]]*\\["

		if (!match(s,pat))
			exit

		x=substr(s,RSTART+RLENGTH)

		instr=0
		esc=0
		depth=0
		obj=""
		inobj=0

		for (i=1;i<=length(x);i++) {

			c=substr(x,i,1)

			if (esc) {
				if (inobj)
					obj=obj c

				esc=0
				continue
			}

			if (c=="\\") {
				if (inobj)
					obj=obj c

				esc=1
				continue
			}

			if (c=="\"") {
				instr=!instr

				if (inobj)
					obj=obj c

				continue
			}

			if (!instr) {

				if (c=="{") {

					if (!inobj) {
						inobj=1
						depth=1
						obj="{"
					}
					else {
						depth++
						obj=obj c
					}

					continue
				}

				if (c=="}" && inobj) {

					depth--
					obj=obj c

					if (depth==0) {

						print obj

						inobj=0
						obj=""
					}

					continue
				}
			}

			if (inobj)
				obj=obj c
		}
	}
	' "$NORMALIZED"
}

###############################################################################
# EXTRACT STA_TABLE
###############################################################################

extract_sta_table()
{
	OBJECT="$1"

	printf '%s' "$OBJECT" |
	awk '
	BEGIN {
		RS=""
	}

	{
		s=$0

		pat="\"sta_table\"[[:space:]]*:[[:space:]]*\\["

		if (!match(s,pat))
			exit

		x=substr(s,RSTART+RLENGTH)

		depth=1
		instr=0
		esc=0
		out=""

		for (i=1;i<=length(x);i++) {

			c=substr(x,i,1)

			if (esc) {
				out=out c
				esc=0
				continue
			}

			if (c=="\\") {
				out=out c
				esc=1
				continue
			}

			if (c=="\"") {
				instr=!instr
				out=out c
				continue
			}

			if (!instr) {

				if (c=="[")
					depth++

				else if (c=="]") {

					depth--

					if (depth==0)
						break
				}
			}

			out=out c
		}

		print out
	}
	'
}

###############################################################################
# SPLIT CLIENT OBJECTS
###############################################################################

split_client_objects()
{
	DATA="$1"

	printf '%s' "$DATA" |
	awk '
	BEGIN {
		RS=""
	}

	{
		s=$0

		while (match(s,/\{[^{}]*\}/)) {

			obj=substr(s,RSTART,RLENGTH)

			if (obj ~ /"mac"[[:space:]]*:/)
				print obj

			s=substr(s,RSTART+RLENGTH)
		}
	}
	'
}

###############################################################################
# FREQUENCY
###############################################################################

frequency_for()
{
	BAND="$1"
	CHANNEL="$2"

	case "$BAND" in

		2g)
			case "$CHANNEL" in
				1) echo 2412 ;;
				2) echo 2417 ;;
				3) echo 2422 ;;
				4) echo 2427 ;;
				5) echo 2432 ;;
				6) echo 2437 ;;
				7) echo 2442 ;;
				8) echo 2447 ;;
				9) echo 2452 ;;
				10) echo 2457 ;;
				11) echo 2462 ;;
				12) echo 2467 ;;
				13) echo 2472 ;;
				14) echo 2484 ;;
				*) echo 0 ;;
			esac
			;;

		5g)
			case "$CHANNEL" in
				''|*[!0-9]*)
					echo 0
					;;
				*)
					echo $((5000 + CHANNEL * 5))
					;;
			esac
			;;

		6g)
			#
			# 6 GHz:
			# frequency = 5950 + channel * 5
			#
			case "$CHANNEL" in
				''|*[!0-9]*)
					echo 0
					;;
				*)
					echo $((5950 + CHANNEL * 5))
					;;
			esac
			;;

		*)
			echo 0
			;;
	esac
}

###############################################################################
# BAND FROM RADIO
###############################################################################

band_from_radio()
{
	case "$1" in
		ng|2g|wifi0)
			echo "2g"
			;;
		na|5g|wifi1)
			echo "5g"
			;;
		6g|ax6)
			echo "6g"
			;;
		*)
			echo ""
			;;
	esac
}

###############################################################################
# ADD VAP
###############################################################################

add_vap()
{
	VAP="$1"

	RADIO="$(object_get "$VAP" radio)"
	CHANNEL="$(object_get "$VAP" channel)"
	ESSID="$(object_get "$VAP" essid)"
	BSSID="$(object_get "$VAP" bssid)"
	NAME="$(object_get "$VAP" name)"
	NUM_STA="$(object_get "$VAP" num_sta)"
	VAP_STATE="$(object_get "$VAP" state)"
	TX_POWER="$(object_get "$VAP" tx_power)"
	RX_BYTES="$(object_get "$VAP" rx_bytes)"
	TX_BYTES="$(object_get "$VAP" tx_bytes)"

	BAND="$(band_from_radio "$RADIO")"

	#
	# Fallback based on channel.
	#
	if [ -z "$BAND" ]; then

		case "$CHANNEL" in
			1|2|3|4|5|6|7|8|9|10|11|12|13|14)
				BAND="2g"
				;;
			*)
				BAND="5g"
				;;
		esac
	fi

	case "$CHANNEL" in
		''|*[!0-9]*)
			CHANNEL=0
			;;
	esac

	case "$NUM_STA" in
		''|*[!0-9]*)
			NUM_STA=0
			;;
	esac

	case "$TX_POWER" in
		''|*[!0-9]*)
			TX_POWER=0
			;;
	esac

	case "$RX_BYTES" in
		''|*[!0-9]*)
			RX_BYTES=0
			;;
	esac

	case "$TX_BYTES" in
		''|*[!0-9]*)
			TX_BYTES=0
			;;
	esac

	FREQUENCY="$(frequency_for "$BAND" "$CHANNEL")"

	printf '{' >> "$VAPFILE"

	printf '"ifname":%s,' \
		"$(jstr "$NAME")" >> "$VAPFILE"

	printf '"ssid":%s,' \
		"$(jstr "$ESSID")" >> "$VAPFILE"

	printf '"frequency":%s,' \
		"$(jnum "$FREQUENCY")" >> "$VAPFILE"

	printf '"band":%s,' \
		"$(jstr "$BAND")" >> "$VAPFILE"

	printf '"bssid":%s,' \
		"$(jstr "$BSSID")" >> "$VAPFILE"

	printf '"channel":%s,' \
		"$(jnum "$CHANNEL")" >> "$VAPFILE"

	printf '"radio":%s,' \
		"$(jstr "$RADIO")" >> "$VAPFILE"

	printf '"clients":%s,' \
		"$(jnum "$NUM_STA")" >> "$VAPFILE"

	printf '"state":%s,' \
		"$(jstr "$VAP_STATE")" >> "$VAPFILE"

	printf '"tx_power":%s,' \
		"$(jnum "$TX_POWER")" >> "$VAPFILE"

	printf '"rx_bytes":%s,' \
		"$(jnum "$RX_BYTES")" >> "$VAPFILE"

	printf '"tx_bytes":%s' \
		"$(jnum "$TX_BYTES")" >> "$VAPFILE"

	printf '}\n' >> "$VAPFILE"

	agent_debug \
		"VAP radio=$RADIO band=$BAND channel=$CHANNEL ssid=$ESSID bssid=$BSSID clients=$NUM_STA"
}

###############################################################################
# RATE FORMAT
###############################################################################

format_rate()
{
	RATE="$1"

	case "$RATE" in
		''|*[!0-9]*)
			echo "0M"
			;;
		0)
			echo "0M"
			;;
		*)
			#
			# mca-dump reports rate in Kbit/s.
			# Example:
			#   58500 -> 58.5M
			#
			awk -v r="$RATE" '
			BEGIN {
				v=r/1000

				if (v == int(v))
					printf "%dM",v
				else
					printf "%.1fM",v
			}'
			;;
	esac
}

###############################################################################
# ADD CLIENT
###############################################################################

add_client()
{
	VAP="$1"
	CLIENT="$2"

	RADIO="$(object_get "$VAP" radio)"
	BAND="$(band_from_radio "$RADIO")"

	CHANNEL="$(object_get "$VAP" channel)"
	SSID="$(object_get "$VAP" essid)"
	BSSID="$(object_get "$VAP" bssid)"

	MAC_CLIENT="$(object_get "$CLIENT" mac)"

	case "$MAC_CLIENT" in
		??:??:??:??:??:??)
			;;
		*)
			return
			;;
	esac

	#
	# Avoid duplicates.
	#
	if grep -qi \
		"\"mac\":\"$(json_escape "$MAC_CLIENT")\"" \
		"$CLIENTFILE" 2>/dev/null
	then
		return
	fi

	HOSTNAME_CLIENT="$(object_get "$CLIENT" hostname)"
	IP_CLIENT="$(object_get "$CLIENT" ip)"

	SIGNAL="$(object_get "$CLIENT" signal)"
	RSSI="$(object_get "$CLIENT" rssi)"
	NOISE="$(object_get "$CLIENT" noise)"

	RX_BYTES="$(object_get "$CLIENT" rx_bytes)"
	TX_BYTES="$(object_get "$CLIENT" tx_bytes)"

	RX_RATE="$(object_get "$CLIENT" rx_rate)"
	TX_RATE="$(object_get "$CLIENT" tx_rate)"

	UPTIME_CLIENT="$(object_get "$CLIENT" uptime)"
	IDLE_TIME="$(object_get "$CLIENT" idletime)"

	AUTHORIZED="$(object_get "$CLIENT" authorized)"

	#
	# Signal is normally already dBm.
	#
	case "$SIGNAL" in
		''|*[!0-9-]*)
			SIGNAL=""
			;;
	esac

	#
	# Legacy APs sometimes only expose RSSI/SNR.
	#
	if [ -z "$SIGNAL" ]; then

		case "$RSSI" in
			''|*[!0-9]*)
				SIGNAL=0
				;;
			*)
				SIGNAL=$((RSSI - 95))
				;;
		esac
	fi

	case "$RSSI" in
		''|*[!0-9-]*)
			RSSI=0
			;;
	esac

	case "$NOISE" in
		''|*[!0-9-]*)
			NOISE=0
			;;
	esac

	case "$RX_BYTES" in
		''|*[!0-9]*)
			RX_BYTES=0
			;;
	esac

	case "$TX_BYTES" in
		''|*[!0-9]*)
			TX_BYTES=0
			;;
	esac

	case "$UPTIME_CLIENT" in
		''|*[!0-9]*)
			UPTIME_CLIENT=0
			;;
	esac

	case "$IDLE_TIME" in
		''|*[!0-9]*)
			IDLE_TIME=0
			;;
	esac

	RX_RATE_FMT="$(format_rate "$RX_RATE")"
	TX_RATE_FMT="$(format_rate "$TX_RATE")"

	printf '{' >> "$CLIENTFILE"

	printf '"ap":%s,' \
		"$(jstr "$HOSTNAME_VAL")" >> "$CLIENTFILE"

	printf '"mac":%s,' \
		"$(jstr "$MAC_CLIENT")" >> "$CLIENTFILE"

	printf '"channel":%s,' \
		"$(jnum "$CHANNEL")" >> "$CLIENTFILE"

	printf '"txrate":%s,' \
		"$(jstr "$TX_RATE_FMT")" >> "$CLIENTFILE"

	printf '"rxrate":%s,' \
		"$(jstr "$RX_RATE_FMT")" >> "$CLIENTFILE"

	printf '"signal":%s,' \
		"$(jnum "$SIGNAL")" >> "$CLIENTFILE"

	printf '"rssi":%s,' \
		"$(jnum "$RSSI")" >> "$CLIENTFILE"

	printf '"noise":%s,' \
		"$(jnum "$NOISE")" >> "$CLIENTFILE"

	printf '"connected":%s,' \
		"$(jnum "$UPTIME_CLIENT")" >> "$CLIENTFILE"

	printf '"lastcommunication":%s,' \
		"$(jnum "$IDLE_TIME")" >> "$CLIENTFILE"

	printf '"idle":%s,' \
		"$(jnum "$IDLE_TIME")" >> "$CLIENTFILE"

	printf '"band":%s,' \
		"$(jstr "$BAND")" >> "$CLIENTFILE"

	printf '"ssid":%s,' \
		"$(jstr "$SSID")" >> "$CLIENTFILE"

	printf '"bssid":%s,' \
		"$(jstr "$BSSID")" >> "$CLIENTFILE"

	printf '"interface":%s,' \
		"$(jstr "$HOSTNAME_VAL")" >> "$CLIENTFILE"

	printf '"ipaddr":%s,' \
		"$(jstr "$IP_CLIENT")" >> "$CLIENTFILE"

	printf '"ip":%s,' \
		"$(jstr "$IP_CLIENT")" >> "$CLIENTFILE"

	printf '"name":%s,' \
		"$(jstr "$HOSTNAME_CLIENT")" >> "$CLIENTFILE"

	printf '"hostname":%s,' \
		"$(jstr "$HOSTNAME_CLIENT")" >> "$CLIENTFILE"

	printf '"rx":%s,' \
		"$(jnum "$RX_BYTES")" >> "$CLIENTFILE"

	printf '"tx":%s,' \
		"$(jnum "$TX_BYTES")" >> "$CLIENTFILE"

	printf '"rx_bytes":%s,' \
		"$(jnum "$RX_BYTES")" >> "$CLIENTFILE"

	printf '"tx_bytes":%s,' \
		"$(jnum "$TX_BYTES")" >> "$CLIENTFILE"

	printf '"authorized":%s' \
		"$(jstr "$AUTHORIZED")" >> "$CLIENTFILE"

	printf '}\n' >> "$CLIENTFILE"

	agent_debug \
		"CLIENT band=$BAND mac=$MAC_CLIENT ip=$IP_CLIENT signal=$SIGNAL channel=$CHANNEL ssid=$SSID"
}

###############################################################################
# PARSE VAPS
###############################################################################

agent_debug "PARSING VAP TABLE"

VAP_OBJECTS="$TMPBASE.vapobjects"

extract_vaps > "$VAP_OBJECTS"

VAP_COUNT=0

while IFS= read -r VAP; do

	[ -n "$VAP" ] || continue

	case "$VAP" in
		\{*\})
			;;
		*)
			continue
			;;
	esac

	add_vap "$VAP"

	VAP_COUNT=$((VAP_COUNT + 1))

	#
	# Parse clients belonging to this exact VAP.
	#
	STA_DATA="$(extract_sta_table "$VAP")"

	if [ -n "$STA_DATA" ]; then

		split_client_objects "$STA_DATA" |
		while IFS= read -r CLIENT; do

			[ -n "$CLIENT" ] || continue

			add_client "$VAP" "$CLIENT"

		done
	fi

done < "$VAP_OBJECTS"

agent_debug "VAPS parsed=$VAP_COUNT"

###############################################################################
# ACTIVE CHANNELS
###############################################################################

CHANNEL2G=0
CHANNEL5G=0
CHANNEL6G=0

while IFS= read -r VAP; do

	[ -n "$VAP" ] || continue

	RADIO="$(object_get "$VAP" radio)"
	CHANNEL="$(object_get "$VAP" channel)"

	case "$CHANNEL" in
		''|*[!0-9]*)
			CHANNEL=0
			;;
	esac

	[ "$CHANNEL" -gt 0 ] 2>/dev/null || continue

	case "$RADIO" in
		ng)
			if [ "$CHANNEL2G" -eq 0 ]; then
				CHANNEL2G="$CHANNEL"
			fi
			;;

		na)
			if [ "$CHANNEL5G" -eq 0 ]; then
				CHANNEL5G="$CHANNEL"
			fi
			;;

		6g|ax6)
			if [ "$CHANNEL6G" -eq 0 ]; then
				CHANNEL6G="$CHANNEL"
			fi
			;;
	esac

done < "$VAP_OBJECTS"

###############################################################################
# OLD FIRMWARE CHANNEL FALLBACK
###############################################################################

if [ "$CHANNEL2G" -eq 0 ]; then

	CHANNEL2G="$(json_get_number ng-channel)"

	case "$CHANNEL2G" in
		''|*[!0-9]*)
			CHANNEL2G=0
			;;
	esac
fi

if [ "$CHANNEL5G" -eq 0 ]; then

	CHANNEL5G="$(json_get_number na-channel)"

	case "$CHANNEL5G" in
		''|*[!0-9]*)
			CHANNEL5G=0
			;;
	esac
fi

if [ "$CHANNEL6G" -eq 0 ]; then

	CHANNEL6G="$(json_get_number 6g-channel)"

	case "$CHANNEL6G" in
		''|*[!0-9]*)
			CHANNEL6G=0
			;;
	esac
fi

agent_debug \
	"CHANNELS 2g=$CHANNEL2G 5g=$CHANNEL5G 6g=$CHANNEL6G"

###############################################################################
# ARRAY BUILDER
###############################################################################

build_array()
{
	FILE="$1"

	printf '['

	FIRST=1

	while IFS= read -r ITEM; do

		[ -n "$ITEM" ] || continue

		if [ "$FIRST" -eq 0 ]; then
			printf ','
		fi

		printf '%s' "$ITEM"

		FIRST=0

	done < "$FILE"

	printf ']'
}

###############################################################################
# CLIENT BAND FILES
###############################################################################

CLIENT2G_FILE="$TMPBASE.clients2g"
CLIENT5G_FILE="$TMPBASE.clients5g"
CLIENT6G_FILE="$TMPBASE.clients6g"

: > "$CLIENT2G_FILE"
: > "$CLIENT5G_FILE"
: > "$CLIENT6G_FILE"

while IFS= read -r CLIENT_JSON; do

	[ -n "$CLIENT_JSON" ] || continue

	BAND="$(
		printf '%s' "$CLIENT_JSON" |
		sed -n 's/.*"band":"\([^"]*\)".*/\1/p'
	)"

	case "$BAND" in
		2g)
			printf '%s\n' "$CLIENT_JSON" >> "$CLIENT2G_FILE"
			;;

		5g)
			printf '%s\n' "$CLIENT_JSON" >> "$CLIENT5G_FILE"
			;;

		6g)
			printf '%s\n' "$CLIENT_JSON" >> "$CLIENT6G_FILE"
			;;
	esac

done < "$CLIENTFILE"

###############################################################################
# COUNTS
###############################################################################

WIFI_COUNT="$(wc -l < "$VAPFILE" 2>/dev/null)"
CLIENT_COUNT="$(wc -l < "$CLIENTFILE" 2>/dev/null)"

CLIENT2G_COUNT="$(wc -l < "$CLIENT2G_FILE" 2>/dev/null)"
CLIENT5G_COUNT="$(wc -l < "$CLIENT5G_FILE" 2>/dev/null)"
CLIENT6G_COUNT="$(wc -l < "$CLIENT6G_FILE" 2>/dev/null)"

case "$WIFI_COUNT" in
	''|*[!0-9]*) WIFI_COUNT=0 ;;
esac

case "$CLIENT_COUNT" in
	''|*[!0-9]*) CLIENT_COUNT=0 ;;
esac

case "$CLIENT2G_COUNT" in
	''|*[!0-9]*) CLIENT2G_COUNT=0 ;;
esac

case "$CLIENT5G_COUNT" in
	''|*[!0-9]*) CLIENT5G_COUNT=0 ;;
esac

case "$CLIENT6G_COUNT" in
	''|*[!0-9]*) CLIENT6G_COUNT=0 ;;
esac

###############################################################################
# ARRAYS
###############################################################################

WIFI_JSON="$(build_array "$VAPFILE")"
CLIENTS_JSON="$(build_array "$CLIENTFILE")"

CLIENTS2G_JSON="$(build_array "$CLIENT2G_FILE")"
CLIENTS5G_JSON="$(build_array "$CLIENT5G_FILE")"
CLIENTS6G_JSON="$(build_array "$CLIENT6G_FILE")"

###############################################################################
# DEBUG
###############################################################################

agent_debug \
	"FINAL hostname=$HOSTNAME_VAL ip=$IPADDR mac=$MAC model=$MODEL version=$SOFTWARE uptime=$UPTIME wifi=$WIFI_COUNT clients=$CLIENT_COUNT 2g=$CHANNEL2G 5g=$CHANNEL5G 6g=$CHANNEL6G"

###############################################################################
# FINAL JSON
###############################################################################

printf '{'

printf '"type":"unifi",'
printf '"platform":"unifi",'

printf '"status":%s,' \
	"$(jstr "$STATUS")"

printf '"ipaddr":%s,' \
	"$(jstr "$IPADDR")"

printf '"ip":%s,' \
	"$(jstr "$IPADDR")"

printf '"mac":%s,' \
	"$(jstr "$MAC")"

printf '"hostname":%s,' \
	"$(jstr "$HOSTNAME_VAL")"

printf '"name":%s,' \
	"$(jstr "$HOSTNAME_VAL")"

printf '"model":%s,' \
	"$(jstr "$MODEL")"

printf '"software":%s,' \
	"$(jstr "$SOFTWARE")"

printf '"version":%s,' \
	"$(jstr "$SOFTWARE")"

printf '"lastcontact":%s,' \
	"$(jnum "$LASTCONTACT")"

printf '"uptime":%s,' \
	"$(jnum "$UPTIME")"

printf '"load":%s,' \
	"$(jstr "$LOAD")"

printf '"clients":%s,' \
	"$(jnum "$CLIENT_COUNT")"

printf '"clients2g":%s,' \
	"$(jnum "$CLIENT2G_COUNT")"

printf '"clients5g":%s,' \
	"$(jnum "$CLIENT5G_COUNT")"

printf '"clients6g":%s,' \
	"$(jnum "$CLIENT6G_COUNT")"

printf '"channel2g":%s,' \
	"$(jnum "$CHANNEL2G")"

printf '"channel5g":%s,' \
	"$(jnum "$CHANNEL5G")"

printf '"channel6g":%s,' \
	"$(jnum "$CHANNEL6G")"

printf '"channels2g":%s,' \
	"$(jnum "$CHANNEL2G")"

printf '"channels5g":%s,' \
	"$(jnum "$CHANNEL5G")"

printf '"channels6g":%s,' \
	"$(jnum "$CHANNEL6G")"

printf '"wifi":%s,' \
	"$WIFI_JSON"

printf '"clientslist":%s,' \
	"$CLIENTS_JSON"

printf '"clientslist2g":%s,' \
	"$CLIENTS2G_JSON"

printf '"clientslist5g":%s,' \
	"$CLIENTS5G_JSON"

printf '"clientslist6g":%s' \
	"$CLIENTS6G_JSON"

printf '}\n'

agent_debug \
	"END SUCCESS wifi=$WIFI_COUNT clients=$CLIENT_COUNT"

exit 0

#!/bin/sh
# Odczyt VLAN-u interfejsu; bez zmian konfiguracji.
apc_device_vlans(){
 local device="$1" depth="${2:-0}" section type vid port
 [ "$depth" -lt 5 ] || return 0
 case "$device" in *.[0-9]*) vid=${device##*.};case "$vid" in *[!0-9]*|'') ;; *) [ "$vid" -ge 1 ] && [ "$vid" -le 4094 ] && printf '%s\n' "$vid" && return 0;; esac;; esac
 for section in $(uci -q show network | sed -n 's/^network\.\([^=]*\)=device$/\1/p'); do
  [ "$(uci -q get "network.$section.name")" = "$device" ] || continue
  type=$(uci -q get "network.$section.type");vid=$(uci -q get "network.$section.vid")
  case "$type:$vid" in 8021q:*|8021ad:*) case "$vid" in ''|*[!0-9]*) ;; *) printf '%s\n' "$vid";; esac;; esac
  if [ "$type" = bridge ]; then for port in $(uci -q get "network.$section.ports"); do apc_device_vlans "$port" "$((depth+1))"; done; fi
 done
}
apc_network_vlan(){
 local device result
 device=$(uci -q get "network.$1.device" || uci -q get "network.$1.ifname")
 result=$(for device in $device; do apc_device_vlans "$device"; done | sort -nu)
 set -- $result
 [ "$#" = 1 ] || return 1
 printf '%s' "$1"
}

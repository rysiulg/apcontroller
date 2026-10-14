#!/bin/sh
# Zgodność starej nazwy skryptu z mechanizmem APController; bez własnego przepisywania sieci.
set -e
group=${1:-};mode=${2:-check};targets=${3:-}
if [ "$group" = --groups ]; then . /lib/functions.sh;show_group(){ printf '%s\n' "$1"; };config_load apcontroller;config_foreach show_group group;exit;fi
case "$mode" in check|verbose) ;; *) echo 'Tryb: check albo verbose (zastosowanie)' >&2;exit 2;;esac
[ -n "$group" ] && [ -n "$targets" ] || { echo 'Użycie: sync-wireless-smart.sh GRUPA check|verbose host1,host4';echo 'Zalecane: panel APController → Wi-Fi → Zapisz i wyślij.';exit 2; }
[ -x /usr/bin/apcontroller-sendconfig ] || { echo 'Zainstaluj podpisany pakiet luci-apcontroller na głównym routerze.' >&2;exit 2; }
exec /usr/bin/apcontroller-sendconfig "$group" "$mode" "$targets"

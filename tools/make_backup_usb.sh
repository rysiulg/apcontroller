#!/bin/sh
set -e
case "${1:-}" in
 --stream)
  umask 077;work=$(mktemp -d /tmp/apc-backup.XXXXXX);trap 'rm -rf "$work"' EXIT
  /sbin/sysupgrade -b "$work/config.tar.gz" >&2;tar -tzf "$work/config.tar.gz" >/dev/null;cat "$work/config.tar.gz";;
 --manual) [ -x /usr/bin/apcontroller-backup ] || { echo 'Brak pakietu zbierania backupów na głównym routerze' >&2;exit 2; };exec /usr/bin/apcontroller-backup run "${2:-}";;
 *) [ ! -f /etc/autobackup.disabled ] || { echo 'Automatyczny backup wyłączony. Ręcznie: make_backup_usb.sh --manual';exit 0; };echo 'Nie skonfigurowano harmonogramu. Użyj --manual na głównym routerze lub --stream z kontrolera.';exit 2;;
esac

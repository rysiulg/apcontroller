#!/bin/sh
# Pobiera pliki; nie konfiguruje sieci, radia, cronów ani firmware.
set -eu
umask 077
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/env.sh"
[ -f "$ENV_FILE" ] || { echo 'Brak env.sh'; exit 2; }
. "$ENV_FILE"
SERVER_URL=${SERVER_SCRIPTS:-}
case "$SERVER_URL" in https://*) ;; *) echo 'Wymagany adres HTTPS'; exit 2;; esac
[ -n "${TOKEN:-}" ] || { echo 'Brak tokenu NAS'; exit 2; }
exec 9>/tmp/sync-scripts-nas.lock
flock -n 9 || exit 0
TMP=$(mktemp -d /tmp/sync-scripts-nas.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
curl -fsS --connect-timeout 10 --max-time 30 -H "Authorization: Bearer $TOKEN" "$SERVER_URL?list=1" -o "$TMP/list"
while IFS='|' read -r name sha size stamp; do
 case "$name" in env.sh|*/*|*[!A-Za-z0-9_.-]*|'') continue;; *.sh) ;; *) continue;; esac
 [ "$name" != make_backup_usb.sh ] || [ ! -f /etc/autobackup.disabled ] || continue
 printf '%s' "$sha" | grep -Eq '^[a-f0-9]{64}$' || { echo "$name: błędna suma w indeksie"; exit 2; }
 curl -fsS --connect-timeout 10 --max-time 30 -H "Authorization: Bearer $TOKEN" "$SERVER_URL?file=$name" -o "$TMP/$name"
 [ "$(sha256sum "$TMP/$name" | cut -d ' ' -f 1)" = "$sha" ] || { echo "$name: SHA256 niezgodna, odrzucono"; exit 2; }
 sh -n "$TMP/$name" || { echo "$name: błędna składnia, odrzucono"; exit 2; }
done < "$TMP/list"
BACKUP=/etc/apcontroller/scripts-backup/$(date +%Y%m%d-%H%M%S)
for file in "$TMP"/*.sh; do
 [ -f "$file" ] || continue
 name=${file##*/}; target="$SCRIPT_DIR/$name"
 [ ! -L "$target" ] || { echo "$name: odrzucono link symboliczny"; exit 2; }
 [ ! -f "$target" ] || [ "$(sha256sum "$target" | cut -d ' ' -f 1)" != "$(sha256sum "$file" | cut -d ' ' -f 1)" ] || continue
 mkdir -p "$BACKUP"
 [ ! -f "$target" ] || cp -p "$target" "$BACKUP/$name"
 cp "$file" "$target.next"; chmod 755 "$target.next"; mv "$target.next" "$target"
 echo "$name: zaktualizowano plik, bez uruchamiania"
done
for path in /scripts/ /etc/apcontroller/; do grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >> /etc/sysupgrade.conf; done

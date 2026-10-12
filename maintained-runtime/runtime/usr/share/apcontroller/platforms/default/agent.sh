#!/bin/sh

if [ -n "${BASEFOLDER:-}" ]; then
        BASEDIR="$BASEFOLDER"
else
        BASEDIR="$(CDPATH= cd -- "$(dirname "$0")" 2>/dev/null && pwd)"
fi

case "$1" in
        poll)
                apc_engine_poll "$BASEDIR/platforms/${APC_PLATFORM}/schema.json"
                ;;
        *)
                exit 1
                ;;
esac

#!/bin/sh

apc_platform_mikrotik_detect()
{
	cat <<'EOF'
if command -v routerboard >/dev/null 2>&1 ||
   [ -d /nova ] ||
   [ -d /flash/rw ] ||
   { [ -f /etc/version ] &&
     grep -qi "mikrotik\|routeros" /etc/version 2>/dev/null; }
then
	echo MIKROTIK
fi
EOF
}
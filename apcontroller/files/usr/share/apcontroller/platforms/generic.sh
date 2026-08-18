#!/bin/sh

apc_platform_generic_detect()
{
	cat <<'EOF'
if command -v hostapd >/dev/null 2>&1 ||
   [ -d /etc/hostapd ] ||
   [ -d /sys/class/net ]
then
	echo GENERIC
fi
EOF
}
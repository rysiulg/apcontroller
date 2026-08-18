#!/bin/sh

apc_platform_omada_detect()
{
	cat <<'EOF'
if command -v cliclientd >/dev/null 2>&1 ||
   command -v tpctl >/dev/null 2>&1 ||
   [ -d /etc/omada ] ||
   [ -d /etc/tplink ] ||
   [ -d /etc/tp-link ]
then
	echo OMADA
fi
EOF
}
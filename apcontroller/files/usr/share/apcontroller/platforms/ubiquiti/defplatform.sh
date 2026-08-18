#!/bin/sh

apc_platform_ubiquiti_detect()
{
	cat <<'EOF'
if command -v mca-cli >/dev/null 2>&1 ||
   command -v mca-cli-op >/dev/null 2>&1 ||
   command -v ubntbox >/dev/null 2>&1 ||
   command -v cfgmtd >/dev/null 2>&1 ||
   command -v syswrapper.sh >/dev/null 2>&1 ||
   command -v ubnt-util >/dev/null 2>&1 ||
   [ -f /etc/ubnt_version ] ||
   [ -f /etc/ubnt_version.info ] ||
   [ -d /etc/ubnt ] ||
   [ -d /etc/ubnt.d ] ||
   { [ -f /etc/version ] &&
     grep -qi "ubiquiti\|ubnt" /etc/version 2>/dev/null; }
then
	echo UBIQUITI
fi
EOF
}
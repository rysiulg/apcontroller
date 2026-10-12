. /usr/share/apcontroller/lib/platform.sh

rm -f /tmp/openwrt-agent.sh

apc_platform_build_agent openwrt /tmp/openwrt-agent.sh

echo "build=$?"
ls -lh /tmp/openwrt-agent.sh

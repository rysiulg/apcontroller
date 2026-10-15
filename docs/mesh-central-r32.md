# Central BATMAN transport (r32)

This optional topology terminates BATMAN on the main router. The main router does not need a radio. Tagged transport VLAN 5 carries BATMAN frames between wired peers; an encrypted 802.11s interface supplies the alternate wireless path. Service VLANs travel inside BATMAN and are bridged to their ordinary networks only at the main router.

Do not enable this by adding a second unmanaged bridge path. Stage the topology with independent rollback and an out-of-band or known working wired recovery path. This release provides the node monitor and Wi-Fi integration; it does not automatically migrate an arbitrary network from LuCI.

## Main router

Keep the physical VLAN-aware bridge and WAN configuration. Enable a BATMAN_V mesh interface and a wired hard-interface on the transport VLAN. Give that transport device a unique MAC, distinct from the LAN gateway and mesh soft-interface. Bridge each service VLAN from the BATMAN soft-interface to its corresponding physical service VLAN in a separate service bridge. Move each logical LAN/guest/IoT interface to that bridge, keeping its address and firewall zone.

Use compatible MTUs and enable BATMAN fragmentation when the transport cannot carry the encapsulated 1500-byte service frame without fragmentation. Check large packets after deployment. Refresh DHCP/firewall state and verify existing VPN addresses and routes after changing a router's L3 devices.

## Node configuration contract

- `network.bat0_eth.apcontroller_transport_mode=central` selects the local `uplink-central` monitor through `uplink-start`.
- `network.bat0_eth.auto=0` leaves wired hard-interface activation to the monitor. Keep the radio mesh hard-interface enabled.
- `network.batman_control` is an isolated static IPv4 interface on the wired transport bridge; set its `apcontroller_gateway` to the main router's transport-only address. It must never be bridged to a service VLAN or forwarded over the mesh. ARP on this segment tests the wired path independently of radio reachability. No default route or DNS belongs to this interface.
- `network.dev_batman.apcontroller_cpu` identifies the CPU Ethernet device used by the local switch, not a dedicated physical uplink port.
- Each service bridge normally lists only `bat0.<VID>` plus its Wi-Fi interfaces. Its `apcontroller_fallback_port` records the corresponding CPU service subinterface, for example `eth0.<VID>`. A `proto none` interface keeps that fallback device available without assigning it an address.

Two good transport probes select wired operation. Three failed probes select mesh operation, disable the wired BATMAN hard-interface, and attach the isolated local Ethernet service subinterfaces for local wired clients. When the transport returns, those ports are detached before enabling the wired hard-interface. Gratuitous ARP refreshes the node's management attachment. BLA and STP remain additional safeguards during transitions; do not disable upstream loop protection.

The monitor uses installed `arping`, BusyBox tools, `jsonfilter`, netifd and BATMAN. Central mode has no `tcpdump`, RAM package-download or Internet dependency at boot. Legacy mode is retained unchanged.

## Wi-Fi synchronization and backup

The OpenWrt Wi-Fi adapter recognizes central mode, uses `bat0.<VID>` for new service bridges and records their fallback Ethernet device. It does not restore a permanent parallel wired bridge path. Back up `/etc/apcontroller/`, the local init scripts and their exact enabled boot symlinks, `/usr/bin/apcontroller-pull`, UCI configuration and authentication material. Package-owned controller templates are restored from the signed repository, rather than copied wholesale through sysupgrade.

Include matching `kmod-batman-adv`, `batctl-default`, `iputils-arping` (or the installed equivalent), mesh-capable `wpad`, `iw` and their dependencies in the upgraded node image. A configuration archive does not reinstall kernel modules. `luci-proto-batman-adv` supplies optional LuCI configuration. Do not restore old kernel binaries onto a new kernel.

## Validation and limits

Test one node at a time. With a hardware-switch CPU link still up, isolate every external wired service and transport VLAN from that CPU, independently schedule restoration, and verify the selected BATMAN path, management, Internet/DNS and guest/IoT DHCP. Restore all exact original memberships and verify return to wired mode. This synthetic test does not substitute for testing an actual wired client on an AP's remaining Ethernet port.

Real deployment tests confirmed radio failover, large frames and DHCP across service VLANs on two nodes with a usable radio link. A third node with approximately -84 to -87 dBm links retained intermittent connectivity but had heavy loss, and its short DHCP probes failed. The full transition ping test on that weak node lost about 60% of packets. Software cannot promise continuity when no usable radio path exists; improve placement or add a relay/radio before relying on that node for critical service. The tests do not establish long-term stability or zero interruption during convergence.

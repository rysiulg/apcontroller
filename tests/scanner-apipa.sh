#!/bin/sh
set -eu
scanner=${SCANNER:-/usr/share/apcontroller/lib/scanner.uc}
dir=$(mktemp -d /tmp/apc-apipa-test.XXXXXX)
trap 'rm -rf "$dir"' EXIT
printf '%s\n' '{"hosts":[],"clients":[]}' > "$dir/status.json"
: > "$dir/alive.txt"
cat > "$dir/neighbors.txt" <<'EOF'
ap-a 14:30:00 B 02:11:22:33:44:55 ethertype 802.1Q (0x8100), length 62: vlan 102, p 0, ethertype ARP, Request who-has 169.254.222.47 tell 0.0.0.0, length 42
ap-a 14:30:02 B 02:11:22:33:44:55 ethertype 802.1Q (0x8100), length 62: vlan 102, p 0, ethertype ARP, Request who-has 169.254.222.47 tell 169.254.222.47, length 42
ap-b 14:31:00 B 02:11:22:33:44:66 ethertype 802.1Q (0x8100), length 62: vlan 12, p 0, ethertype ARP, Request who-has 169.254.112.17 tell 0.0.0.0, length 42
ap-c 14:32:00 02:11:22:33:44:77 > ff:ff:ff:ff:ff:ff, ethertype ARP (0x0806), length 42: Reply 169.254.10.20 is-at 02:11:22:33:44:77, length 28
ap-d 14:32:01 02:11:22:33:44:88 > 02:11:22:33:44:99, ethertype IPv4 (0x0800), length 62: 169.254.10.21.1000 > 169.254.10.22.2000: UDP, length 20
ap-e 192.168.88.1 0x1 0x2 02:11:22:33:44:aa * br0
EOF
ucode "$scanner" build "$dir" 192.168.88.0/22
ucode -e 'import {readfile} from "fs";let r=json(readfile(ARGV[0]));function one(ip){let a=filter(r.hosts,h=>h.ip==ip);if(length(a)!=1)die("Missing/duplicate "+ip);return a[0];}let a=one("169.254.222.47");if(a.mac!="02:11:22:33:44:55"||!a.apipa_confirmed||index(a.source,"VLAN 102")<0)die("Cooked/VLAN announcement");let b=one("169.254.112.17");if(b.apipa_confirmed||index(b.status,"Sonda")<0)die("Probe confused with assignment");if(one("169.254.10.20").mac!="02:11:22:33:44:77")die("ARP reply MAC");if(one("169.254.10.21").mac!="02:11:22:33:44:88")die("IPv4 source MAC");if(one("192.168.88.1").mac!="02:11:22:33:44:aa")die("Neighbor regression");print("SCANNER_APIPA_REGRESSIONS_OK\n");' "$dir/result.json.next"

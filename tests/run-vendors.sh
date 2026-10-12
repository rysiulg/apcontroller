#!/bin/sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d /tmp/apcontroller-vendor-tests.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
for vendor in unifi omada air; do
    ucode "$root/runtime/usr/share/apcontroller/lib/vendor-status.uc" < "$root/tests/vendor-$vendor.json" > "$tmp/$vendor.json"
done
export APC_VENDOR_TEST_DIR="$tmp"
ucode -e 'import {readfile} from "fs";let p=getenv("APC_VENDOR_TEST_DIR");for(let v in ["unifi","omada","air"]){let h=json(readfile(p+"/"+v+".json")),c=h.clientslist2g[0];if(h.mac!="02:00:00:00:00:01"||!c||c.mac!="02:00:00:00:00:03"||c.ip!="192.0.2.3")exit(1);if(v=="unifi"&&(c.hostname!="Client \"test\""||index(c.ssid,"\\ backslash")<0||c.tx_retries!=7))exit(1);if(v=="omada"&&(c.signal!=-37||c.txrate!="52M"))exit(1);print(v+" parser: OK\n");}'

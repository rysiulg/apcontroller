#!/bin/sh
apc_vendor_poll() (
    platform=$1; host=$2; port=$3; username=$4; password=$5; keyfile=$6; usekeyfile=$7; output=$8
    umask 077
    raw=$(mktemp -d /tmp/apcontroller-vendor.XXXXXX) || exit 1
    trap 'if [ -n "${SEXPECT_SOCKFILE:-}" ]; then sexpect kill >/dev/null 2>&1 || true; fi; rm -rf "$raw"' EXIT
    if [ "$platform" = omada ]; then
        command -v sexpect >/dev/null 2>&1 || exit 1
        export SEXPECT_SOCKFILE="$raw/cli.sock"
        args=$(apc_ssh_options "$port" "$keyfile" "$usekeyfile")
        sexpect spawn -t 8 -ttl 90 ssh -tt $args -o PreferredAuthentications=password,publickey "$username@$host" >/dev/null || exit 1
        sexpect expect -t 8 -re '([Pp]assword:|EAP[>#])' > "$raw/login" || exit 1
        if grep -qi 'password:' "$raw/login"; then export APC_VENDOR_PASSWORD="$password"; sexpect send -enter -env APC_VENDOR_PASSWORD; unset APC_VENDOR_PASSWORD; sexpect expect -t 8 -re 'EAP[>#]' > "$raw/login" || exit 1; fi
        if ! grep -q 'EAP#' "$raw/login"; then sexpect send -enter enable; sexpect expect -t 8 -re 'EAP#' >/dev/null || exit 1; fi
        : > "$raw/cli"
        for command in 'show version' 'show uptime' 'show network status' 'show wifi detail' 'show station info' 'show arp table'; do
            sexpect send -enter "$command" || exit 1
            sexpect expect -t 10 -re 'EAP#' >> "$raw/cli" || exit 1
        done
        sexpect kill >/dev/null 2>&1 || true
    else
        apc_ssh_exec "$host" "$port" "$username" "$password" "$keyfile" "$usekeyfile" 'mca-dump 2>/dev/null' > "$raw/mca" 2>/dev/null || true
        if [ ! -s "$raw/mca" ]; then
            apc_ssh_exec "$host" "$port" "$username" "$password" "$keyfile" "$usekeyfile" 'ubntbox mca-status 2>/dev/null' > "$raw/air" 2>/dev/null || exit 1
            apc_ssh_exec "$host" "$port" "$username" "$password" "$keyfile" "$usekeyfile" 'iwconfig 2>/dev/null' > "$raw/wireless" 2>/dev/null || true
            apc_ssh_exec "$host" "$port" "$username" "$password" "$keyfile" "$usekeyfile" 'wstalist 2>/dev/null' > "$raw/stations" 2>/dev/null || true
        fi
    fi
    export APC_VENDOR_RAW_DIR="$raw" APC_VENDOR_IP="$host" APC_VENDOR_PLATFORM="$platform"
    ucode -e 'import {readfile} from "fs";let p=getenv("APC_VENDOR_RAW_DIR");let m=null;try{m=json(readfile(p+"/mca"));}catch(e){}print(sprintf("%J\n",{ip:getenv("APC_VENDOR_IP"),platform:getenv("APC_VENDOR_PLATFORM"),cli:readfile(p+"/cli"),data:{mca:m,air:readfile(p+"/air"),wireless:readfile(p+"/wireless"),stations:readfile(p+"/stations")}}));' |
        ucode "${LIBFOLDER}/vendor-status.uc" > "$output"
)

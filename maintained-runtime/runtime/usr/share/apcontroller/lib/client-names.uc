#!/usr/bin/ucode
import { readfile } from 'fs';
import { connect } from 'ubus';
import { cursor } from 'uci';
let data = json(readfile('/dev/stdin'));
let cfg = cursor(), bus = connect(), hints = {}, aliases = {}, reservations = {};
try { hints = bus.call('luci-rpc', 'getHostHints', {}) || {}; } catch (e) {}
function validName(value) {
    return type(value) == 'string' && trim(value) != '' && value != '*' && value != 'unknown';
}
function collectNames(target, section) {
    if (!validName(section.name)) return;
    let macs = type(section.mac) == 'array' ? section.mac : split(section.mac || '', ' ');
    for (let i = 0; i < length(macs); i++) if (macs[i]) target[uc(macs[i])] = section.name;
}
cfg.foreach('dhcp', 'host', (section) => collectNames(reservations, section));
cfg.foreach('apcontroller', 'client', (section) => collectNames(aliases, section));
let bands = ['2g', '5g', '6g'];
for (let i = 0; i < length(data.hosts || []); i++) {
    let host = data.hosts[i];
    host['.lastcontact'] = host.lastcontact ?? -1;
    for (let b = 0; b < length(bands); b++) {
        let clients = host['clientslist' + bands[b]] || [];
        for (let j = 0; j < length(clients); j++) {
            let client = clients[j], mac = uc(client.mac || ''), hint = hints[mac] || {};
            client.mac = mac;
            client.name = validName(client.name) ? client.name : (client.hostname || '');
            client.ipaddr = client.ipaddr || client.ip || '';
            client.wifi = client.wifi || client.ssid || '';
            client.name_source = validName(client.name) ? 'agent' : 'unknown';
            if (validName(aliases[mac])) { client.name = aliases[mac]; client.name_source = 'alias'; }
            else if (validName(reservations[mac])) { client.name = reservations[mac]; client.name_source = 'dhcp-static'; }
            else if (!validName(client.name) && validName(hint.name)) { client.name = hint.name; client.name_source = 'router-hints'; }
            if (!validName(client.name)) client.name = '';
            if ((!client.ipaddr || client.ipaddr == '*') && type(hint.ipaddrs) == 'array') client.ipaddr = join(', ', hint.ipaddrs);
        }
    }
}
print(sprintf('%J\n', data));

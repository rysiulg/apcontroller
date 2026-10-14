#!/usr/bin/ucode
import { readfile } from 'fs';
import { connect } from 'ubus';
import { cursor } from 'uci';
let data = json(readfile('/dev/stdin'));
let cfg = cursor(), bus = connect(), hints = {}, aliases = {}, reservations = {};
let snapshots={}, verified={};
let remoteHints={}, cachePath='/tmp/apcontroller';
cfg.foreach('apcontroller','global',(section)=>{if(section.path)cachePath=section.path;});
try { for(let lease in json(readfile('/etc/apcontroller/dhcp-zacisze.json')).leases||[]) {
    let address=uc(lease['mac-address']||'');
    if(address)remoteHints[address]={name:lease.comment||lease['host-name']||'',ipaddrs:[lease['active-address']||lease.address||'']};
} } catch(e) {}
try { for(let d in json(readfile('/etc/apcontroller/discovery.json')).devices||[]) if(d.normalized)snapshots[d.ip]=d.normalized; } catch(e) {}
cfg.foreach('apcontroller','host',(section)=>{if(section.verification=='1')verified[section['.name']]=true;});
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
    if(match(host.ipaddr||'',/^[0-9A-Za-z.:-]+$/) && match(host.section||'',/^[A-Za-z0-9_]+$/)) {
        try { let raw=json(readfile(cachePath+'/'+host.ipaddr+'-'+host.section)); for(let k in ['cpu','memory_total','memory_used','memory_free','radio_stats','interfaces','radio_mode','capabilities'])if(raw[k]!=null)host[k]=raw[k]; } catch(e) {}
    }
    if(verified[host.section] && !host.enabled && snapshots[host.ipaddr]) {
        for(let k,v in snapshots[host.ipaddr]) if(k!='ipaddr' && k!='platform')host[k]=v;
        host.platform=snapshots[host.ipaddr].platform;host.verification=true;host.online=0;
        for(let b in ['2g','5g','6g'])host['clients'+b]=length(host['clientslist'+b]||[]);
    }
    host['.lastcontact'] = host.lastcontact ?? -1;
    for (let b = 0; b < length(bands); b++) {
        let clients = host['clientslist' + bands[b]] || [];
        for (let j = 0; j < length(clients); j++) {
            let client = clients[j], mac = uc(client.mac || ''), hint = hints[mac] || {};
            client.mac = mac;
            if(client.rx==null&&client.rx_bytes!=null)client.rx=client.rx_bytes;
            if(client.tx==null&&client.tx_bytes!=null)client.tx=client.tx_bytes;
            client.name = validName(client.name) ? client.name : (client.hostname || '');
            client.ipaddr = client.ipaddr || client.ip || '';
            client.ssid = client.ssid || (type(client.wifi)=='string'?client.wifi:'') || '';
            if(type(client.wifi)!='int' && type(client.wifi)!='double')client.wifi=null;
            client.name_source = validName(client.name) ? 'agent' : 'unknown';
            if (validName(aliases[mac])) { client.name = aliases[mac]; client.name_source = 'alias'; }
            else if (validName(reservations[mac])) { client.name = reservations[mac]; client.name_source = 'dhcp-static'; }
            else if (!validName(client.name) && validName(hint.name)) { client.name = hint.name; client.name_source = 'router-hints'; }
            if(!validName(client.name) && validName(remoteHints[mac]?.name)){client.name=remoteHints[mac].name;client.name_source='dhcp-zacisze';}
            if (!validName(client.name)) client.name = '';
            if ((!client.ipaddr || client.ipaddr == '*') && type(hint.ipaddrs) == 'array') client.ipaddr = join(', ', hint.ipaddrs);
            if(!client.ipaddr && remoteHints[mac])client.ipaddr=join(', ',remoteHints[mac].ipaddrs);
        }
    }
}
print(sprintf('%J\n', data));

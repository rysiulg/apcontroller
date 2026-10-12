#!/usr/bin/ucode
import { readfile } from 'fs';
let input=json(readfile('/dev/stdin')), data=input.data||{}, host={type:'ap',platform:input.platform||'ubiquiti',ipaddr:input.ip,mac:'',hostname:'',model:'',software:'',uptime:0,load:'',wifi:[],clientslist2g:[],clientslist5g:[],clientslist6g:[]};
function num(v) { return +v||0; }
function mac(v) { return uc(replace(v||'', /-/g, ':')); }
function band(f,c) { return f>=5925?'6g':f>=4000?'5g':f>=2000?'2g':c>14?'5g':'2g'; }
function rate(v) { return v==null?'':sprintf('%.1fM',num(v)/1000); }
function capture(text,pattern,index) { let m=match(text||'',pattern); return m?m[index??1]:''; }
function addClient(client,b) { if(match(client.mac||'',/^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/)) push(host['clientslist'+b],client); }
function wifiBlocks(text) {
    let current=null;
    for(let line in split(replace(text||'', /\r/g, ''),'\n')) {
        let m=match(line,/^([a-zA-Z0-9_.-]+)\s+IEEE\s+802\.11([^ ]*)\s+ESSID:"(.*)"/);
        if(m) { current={interface:m[1],ifname:m[1],ssid:m[3],wifi: m[2]=='ax'?6:m[2]=='ac'?5:m[2]=='ng'||m[2]=='n'?4:3}; push(host.wifi,current); }
        if(!current) continue;
        m=match(line,/Frequency:\s*([0-9.]+)\s*GHz/);
        if(m) { current.frequency=num(m[1])*1000; current.band=band(current.frequency,0); current.channel=current.frequency==2484?14:current.band=='2g'?int((current.frequency-2407)/5):current.band=='5g'?int((current.frequency-5000)/5):int((current.frequency-5950)/5); }
        m=match(line,/Access Point:\s*([0-9A-Fa-f:]{17})/); if(m) current.bssid=mac(m[1]);
    }
}
if(type(data.mca)=='object' && data.mca.mac) {
    let m=data.mca;
    host.mac=mac(m.mac); host.hostname=m.hostname||''; host.model=m.model_display||m.model||''; host.software=m.version||''; host.uptime=num(m.uptime||m['system-stats']?.uptime);
    host.load=sprintf('%s %s %s',m.sys_stats?.loadavg_1||'',m.sys_stats?.loadavg_5||'',m.sys_stats?.loadavg_15||'');
    for(let vap in m.vap_table||[]) {
        let b=band(num(vap.freq),num(vap.channel)); if(vap.radio=='6g'||vap.radio=='ax6')b='6g';
        push(host.wifi,{interface:vap.name,ifname:vap.name,ssid:vap.essid||'',bssid:mac(vap.bssid),channel:num(vap.channel),band:b,tx_retries:num(vap.tx_retries),tx_packets:num(vap.tx_packets)});
        for(let s in vap.sta_table||[]) {
            let c={mac:mac(s.mac),hostname:s.hostname||s.name||'',ip:s.ip||'',ssid:vap.essid||'',interface:vap.name,ap:vap.name,band:b,signal:s.signal??null,connected:num(s.uptime),idle:num(s.idletime),rx_bytes:num(s.rx_bytes),tx_bytes:num(s.tx_bytes),rxrate:rate(s.rx_rate),txrate:rate(s.tx_rate)};
            for(let k in ['tx_retries','tx_packets','rx_packets','tx_failed']) if(s[k]!=null)c[k]=num(s[k]);
            addClient(c,b);
        }
    }
}
else if(input.cli) {
    host.platform='omada'; let cli=replace(input.cli,/\r/g,'');
    host.software=capture(cli,/\n([0-9]+\.[0-9]+\.[0-9]+ Build[^\n]*)/); host.model='Omada EAP (CLI)';
    host.mac=mac(capture(cli,/br0\s+Link encap:Ethernet\s+HWaddr\s+([0-9A-Fa-f:]{17})/));
    let days=num(capture(cli,/up\s+([0-9]+) days?,/)), clock=match(cli,/up\s+([0-9]+ days?,\s*)?([0-9]+):([0-9]+),/);
    host.uptime=days*86400+(clock?num(clock[2])*3600+num(clock[3])*60:0); host.load=capture(cli,/load average:\s*([^\n]+)/);
    wifiBlocks(cli);
    let arp={}; for(let m in match(cli,/\(([0-9.]+)\) at ([0-9a-fA-F:]{17})/g)||[]) arp[mac(m[2])]=m[1];
    for(let line in split(cli,'\n')) {
        let m=match(line,/^\s*(ath[0-9]+)\s+([0-9]+)\s+([0-9a-fA-F:-]{17})\s+(\S+)\s+(\S+)\s+(-?[0-9]+)\s+([0-9]+)s\s+([0-9]+)s/);
        if(!m)continue;
        let w=null;for(let x in host.wifi)if(x.interface==m[1]){w=x;break;}
        let b=w?.band||band(0,num(m[2])), address=mac(m[3]);
        addClient({mac:address,ip:arp[address]||'',hostname:'',ssid:w?.ssid||'',ap:m[1],interface:m[1],band:b,signal:num(m[6]),connected:num(m[7]),idle:num(m[8]),txrate:m[4],rxrate:m[5]},b);
    }
}
else if(type(data.air)=='string' && index(data.air,'deviceName=')>=0) {
    let values={}; for(let line in split(replace(data.air,/\r/g,''),'\n')) for(let part in split(line,',')) {let p=index(part,'=');if(p>=0)values[substr(part,0,p)]=substr(part,p+1);}
    host.hostname=values.deviceName||'';host.mac=mac(values.deviceId);host.model=values.platform||'';host.software=values.firmwareVersion||'';host.uptime=num(values.uptime);host.load=values.loadavg||'';
    wifiBlocks(data.wireless); let stations=[];
    let wireless=replace(data.wireless||'',/\r/g,''), start=index(wireless,'\n[\n');
    try { stations=json(data.stations||(start>=0?substr(wireless,start+1):'')); } catch(e) {}
    for(let s in stations||[]) {
        let w=host.wifi[0]||{},b=w.band||band(num(values.freq),0);
        addClient({mac:mac(s.mac),hostname:s.name||'',ip:s.lastip||'',ssid:values.essid||w.ssid||'',ap:w.interface||'ath0',interface:w.interface||'ath0',band:b,signal:s.signal??null,connected:num(s.uptime),idle:num(s.idle),rxrate:s.rx==null?'':sprintf('%.1fM',num(s.rx)),txrate:s.tx==null?'':sprintf('%.1fM',num(s.tx)),rx_bytes:num(s.stats?.rx_bytes),tx_bytes:num(s.stats?.tx_bytes),ccq:s.ccq??null},b);
    }
    host.radio_mode=values.wlanOpmode||'';
}
else { print('{"error":"vendor_data_missing"}\n'); exit(1); }
if(!match(host.mac,/^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/)) {print('{"error":"vendor_mac_missing"}\n');exit(1);}
print(sprintf('%J\n',host));

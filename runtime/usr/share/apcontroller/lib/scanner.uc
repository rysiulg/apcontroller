import {readfile,writefile} from 'fs';
import {cursor} from 'uci';
let c=cursor(),action=ARGV[0]||'report',dir=ARGV[1]||'/etc/apcontroller/scanner';
function ipnum(ip){let a=split(ip,'.');if(length(a)!=4)return null;let n=0;for(let v in a){if(!match(v,/^\d+$/)||int(v)>255)return null;n=n*256+int(v);}return n;}
function ipstr(n){return join('.',map([16777216,65536,256,1],v=>int(n/v)%256));}
function subnetSize(bits){let n=1;for(let i=bits;i<32;i++)n*=2;return n;}
function network(value,bits){let n=ipnum(value);if(n==null||bits<22||bits>30)return null;let size=subnetSize(bits),base=int(n/size)*size;return ipstr(base)+'/'+bits;}
let scopes=[];
function scope(v){if(v&&match(v,/^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/)&&index(scopes,v)<0)push(scopes,v);}
c.foreach('network','interface',p=>{if(p.proto!='static')return;let ips=type(p.ipaddr)=='array'?p.ipaddr:[p.ipaddr];for(let ip in ips){if(!ip)continue;let a=split(ip,'/'),bits=a[1]?int(a[1]):24;if(!a[1]&&p.netmask){bits=0;for(let b in split(p.netmask,'.')){let x=int(b);while(x){bits+=x%2;x=int(x/2);}}}scope(network(a[0],bits));}});
c.foreach('multivpn','vpn',p=>{let a=split(p.remote_subnet||'','/');if(p.enabled=='1')scope(network(a[0],int(a[1])));});
if(action=='targets'){let selected=ARGV[2];if(index(scopes,selected)<0)die('Wybierz skonfigurowaną prywatną podsieć /22–/30\n');let a=split(selected,'/'),base=ipnum(a[0]),size=subnetSize(int(a[1]));for(let i=1;i<size-1;i++)printf('%s\n',ipstr(base+i));exit(0);}
if(action=='report'){let result={running:false,hosts:[],updated:0};try{result=json(readfile(dir+'/result.json'));}catch(e){}result.scopes=scopes;printf('%J\n',result);exit(0);}
let rows={},leases={},names={};
for(let line in split(readfile('/tmp/dhcp.leases')||'','\n')){let f=split(trim(line),/\s+/);if(length(f)>3){leases[lc(f[1])]=f[2];if(f[3]!='*')names[lc(f[1])]=f[3];}}
try{let dhcp=json(readfile('/etc/apcontroller/dhcp-zacisze.json'));for(let p in dhcp.leases||[]){let mac=lc(p.mac||p['mac-address']||'');if(p.status=='bound')leases[mac]=p.ip||p.address;if(p.name||p['host-name'])names[mac]=p.name||p['host-name'];}}catch(e){}
function add(ip,mac,name,source){ip=ip||'';mac=lc(mac||'');if(!mac&&ip){rows['ip|'+ip]={ip:ip,mac:'—',name:name||'',source:source,dhcp:false,status:'Odpowiada na ICMP; MAC/DHCP nieznane'};return;}if(!match(mac,/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/)||mac=='00:00:00:00:00:00')return;if(ip&&ipnum(ip)==null)return;let key=mac+'|'+ip;if(!rows[key])rows[key]={ip:ip,mac:mac,name:name||names[mac]||'',source:source};else if(index(rows[key].source,source)<0)rows[key].source+=', '+source;rows[key].dhcp=leases[mac]==ip;rows[key].status=substr(ip,0,8)=='169.254.'?'Fallback 169.254 — sprawdź DHCP':!ip?'Wi-Fi bez odczytanego IP':rows[key].dhcp?'DHCP potwierdzone':'Bez potwierdzonej dzierżawy / możliwy statyczny IP';}
try{let status=json(readfile(dir+'/status.json'));for(let h in status.hosts||[]){add(h.ipaddr,h.mac,h.name,'APController');for(let p in h.clients||[])add(p.ipaddr||p.ip,p.mac,p.name,h.name||h.ipaddr);}for(let p in status.clients||[])add(p.ipaddr||p.ip,p.mac,p.name,p.ap_name||'Wi-Fi');}catch(e){}
for(let line in split(readfile(dir+'/neighbors.txt')||'','\n')){let f=split(trim(line),/\s+/);if(length(f)>4&&ipnum(f[1])!=null&&f[3]=='0x2')add(f[1],f[4],'',f[0]);let m=match(line,/^(\S+)\s+(\d+\.\d+\.\d+\.\d+).*lladdr\s+([0-9a-f:]+)/i);if(m)add(m[2],m[3],'',m[1]);let arp=match(line,/^(\S+).*([0-9a-f]{2}(:[0-9a-f]{2}){5})\s+>.*ARP,.*(tell|Reply)\s+(169\.254\.\d+\.\d+)/i);if(arp)add(arp[5],arp[2],'',arp[1]);}
for(let ip in split(readfile(dir+'/alive.txt')||'','\n')){ip=trim(ip);if(!ip)continue;let found=false;for(let k in keys(rows))if(rows[k].ip==ip){rows[k].active_seen=true;found=true;}if(!found)add(ip,'','','ICMP skan');}
let result={running:false,updated:time(),scope:ARGV[2],hosts:values(rows),scopes:scopes,note:'ARP i klienci Wi-Fi nie pokazują wszystkich urządzeń. Brak DHCP może oznaczać IP statyczny. Fallback 169.254 wykrywany lokalnie na routerze i dostępnych AP, nie przez routing VPN.'};writefile(dir+'/result.json.next',sprintf('%J',result));

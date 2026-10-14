import {cursor} from 'uci';
import {readfile,writefile,mkdir,rename,unlink,popen} from 'fs';
let c=cursor(),action=ARGV[0]||'publish',only=ARGV[1]||'',base='/etc/apcontroller/desired';
if(action!='publish'||!match(only,/^[A-Za-z0-9_,]*$/))die('Nieprawidłowa operacja/lista AP');
function arr(v){return type(v)=='array'?v:v?[v]:[];}
function cmd(v){let p=popen(v,'r'),out=p.read('all'),code=p.close();if(code)die('Operacja budowania konfiguracji nie powiodła się');return trim(out);}
function vid(device,depth){
 if(depth>5)return [];let m=match(device||'',/\.([0-9]+)$/);if(m&&int(m[1])>=1&&int(m[1])<=4094)return [m[1]];
 let values=[];c.foreach('network','device',n=>{if(n.name!=device)return;if((n.type=='8021q'||n.type=='8021ad')&&n.vid)push(values,''+n.vid);if(n.type=='bridge')for(let p in arr(n.ports))push(values,...vid(p,depth+1));});return values;
}
function network_vlan(name){if(name=='lan')return '';let values=[];for(let dev in arr(c.get('network',name,'device')||c.get('network',name,'ifname')))push(values,...vid(dev,0));let unique=[];for(let v in values)if(index(unique,v)<0)push(unique,v);return length(unique)==1?unique[0]:'';}
let hosts=[],groups=[],selected=only?split(only,','):[];c.foreach('apcontroller','host',h=>push(hosts,h));c.foreach('apcontroller','group',g=>push(groups,g));
for(let id in selected)if(!length(filter(hosts,h=>h['.name']==id)))die('Nieznane AP '+id);
let jobs=[],adoption=json(readfile(base+'/adoption.json')||'{}');
for(let h in hosts){
 let id=h['.name'];if(h.enabled!='1'||h.platform!='openwrt'||(length(selected)&&index(selected,id)<0))continue;if(!match(id,/^[A-Za-z0-9_]+$/))die('Nieprawidłowy identyfikator AP');
 let wifi={},script=false;
 for(let g in groups){if(index(arr(g.host),id)<0)continue;for(let wid in arr(g.wifi)){let w=c.get_all('apcontroller',wid);if(!w||w['.type']!='wifi')continue;if(!match(wid,/^[A-Za-z0-9_]+$/))die('Nieprawidłowy identyfikator Wi-Fi');let extra=g.useadditionalscript=='1';script=script||extra;
  for(let band in arr(w.band)){let key=wid+':'+band,v={id:wid,band:band,network:w.network||'lan',vlan_id:(w.vlan_auto??'1')=='1'?network_vlan(w.network||'lan'):(w.vlan_id||''),ssid:w.ssid||'',encryption:w.encryption||'none',key:w.key||'',enabled:int(w.enabled??'1'),hidden:int(w.hidden||'0'),isolate:int(w.isolate||'0'),macfilter:w.macfilter||'disable',maclist:arr(w.maclist),use_as:extra?1:0};if(wifi[key]?.use_as)v.use_as=1;wifi[key]=v;}
 }}
 let definitions=[];for(let key in sort(keys(wifi)))push(definitions,wifi[key]);let seen={};for(let w in definitions){let collision=w.ssid+':'+w.band;if(seen[collision])die('Dwa szablony tego samego SSID/pasma dla '+id);seen[collision]=true;}
 push(jobs,{id:id,wifis:definitions,script:script,adopt:adoption[id]||[]});
}
for(let j in jobs){
 let dir=base+'/'+j.id;mkdir(dir,0700);let stage=dir+'/stage';mkdir(stage,0700);
 let fields=['payload','setconfig','vlan.sh','apply.sh'];
 writefile(stage+'/payload',sprintf('%J\n',{delete:0,managed_only:1,wifis:j.wifis,adopt:j.adopt}));
 writefile(stage+'/setconfig',readfile('/usr/share/apcontroller/platforms/openwrt/setconfig'));
 writefile(stage+'/vlan.sh',readfile('/usr/share/apcontroller/lib/network-vlan.sh'));
 writefile(stage+'/apply.sh','#!/bin/sh\nset -e\ncd "$(dirname "$0")"\nAPC_PREFLIGHT=1 sh ./setconfig ./payload\nsh ./setconfig ./payload\n');
 if(j.script){push(fields,'apcontroller.user','apcontroller-agent-as');writefile(stage+'/apcontroller.user',readfile('/usr/share/apcontroller/apcontroller.user')||'');writefile(stage+'/apcontroller-agent-as',readfile('/usr/share/apcontroller/apcontroller-agent-as'));}
 let revision=cmd('cd '+stage+' && sha256sum '+join(' ',fields)+' | sha256sum | cut -d " " -f 1');writefile(stage+'/REVISION',revision+'\n');
 if(trim(readfile(dir+'/revision')||'')!=revision){cmd('tar -cf '+dir+'/current.next -C '+stage+' '+join(' ',fields)+' REVISION');rename(dir+'/current.next',dir+'/current.tar');writefile(dir+'/revision.next',revision+'\n');rename(dir+'/revision.next',dir+'/revision');}
 writefile(dir+'/summary.json',sprintf('%J\n',{host:j.id,revision:revision,wifi:map(j.wifis,w=>({id:w.id,ssid:w.ssid,band:w.band,network:w.network,vlan:w.vlan_id})),updated:time()}));
 for(let name in [...fields,'REVISION','apcontroller.user','apcontroller-agent-as'])unlink(stage+'/'+name);
 printf('%s: zapisano aktualny stan (%d sieci/pasm), wersja %s\n',j.id,length(j.wifis),substr(revision,0,12));
}

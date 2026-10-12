import { readfile, stat } from 'fs';
import { cursor } from 'uci';
import { connect } from 'ubus';
let cfg=cursor(), profiles=[], action=ARGV[0]||'status', selected=ARGV[1]||'', bus=connect();
let owned={};for(let line in split(readfile('/etc/apcontroller/vpn-managed')||'','\n')){let a=split(trim(line),' ');if(length(a)==4)owned[a[0]]={type:a[1],interface:a[2],zone:a[3]};}
function identifier(v){return type(v)=='string'&&match(v,/^[a-z][a-z0-9_]{0,11}$/);}
function cidr(v){
    let m=match(v||'',/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/);if(!m)return null;
    let n=0;for(let i=1;i<5;i++){let b=int(m[i]);if(b>255)return null;n=n*256+b;}
    let bits=int(m[5]);if(bits<1||bits>32)return null;let size=1;for(let i=bits;i<32;i++)size*=2;let base=int(n/size)*size;
    if(n!=base)return null;return {base:base,end:base+size-1};
}
function path(v,kind){return type(v)=='string'&&match(v,kind=='key'?/^\/etc\/swanctl\/private\/[A-Za-z0-9_.-]+\.pem$/:/^\/etc\/swanctl\/(x509|x509ca)\/[A-Za-z0-9_.-]+\.pem$/)&&stat(v);}
cfg.foreach('apcontroller','vpn',p=>{
    let id=p['.name'], err='';p.id=id;
    if(!identifier(id)||!identifier(p.interface)||!identifier(p.zone))err='Nieprawidłowa nazwa profilu, interfejsu lub strefy';
    else if(owned[id]&&owned[id].type!=p.type)err='Nie można zmienić typu istniejącego profilu; dodaj nowy profil';
    else if(!cidr(p.local_subnet)||!cidr(p.remote_subnet))err='Wymagane prawidłowe adresy sieci IPv4 z maską';
    else if(p.mode!='marm-only'&&p.mode!='both')err='Nieprawidłowy kierunek dostępu';
    else if(p.type=='existing'){
        if(cfg.get('network',p.interface)!='interface'||cfg.get('firewall',p.zone)!='zone')err='Nie znaleziono istniejącego interfejsu/strefy';
    }else if(p.type=='ikev2'){
        if((cfg.get('network',p.interface)&&(owned[id]||{}).interface!=p.interface)||(cfg.get('firewall',p.zone)&&(owned[id]||{}).zone!=p.zone))err='Nie można zastąpić istniejącego interfejsu lub strefy innym profilem VPN';
        else if(owned[id]&&(owned[id].interface!=p.interface||owned[id].zone!=p.zone))err='Po utworzeniu IKE nazwy interfejsu/strefy są stałe; utwórz nowy profil dla innego przypisania';
        else if(!match(p.server||'',/^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$/)||!match(p.remote_id||'',/^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$/))err='Nieprawidłowy serwer lub jego tożsamość';
        else if(!match(p.ifid||'',/^\d+$/)||int(p.ifid)<10||int(p.ifid)>4095)err='Identyfikator XFRM musi być z zakresu 10–4095';
        else if(!path(p.cert,'cert')||!path(p.ca,'ca')||!path(p.key,'key'))err='Brak certyfikatów lub klucza w /etc/swanctl';
        else if(p.mode=='both')err='Certyfikat klienta/VIP obsługuje dostęp z MARM; obustronny site-to-site wymaga konfiguracji serwera';
    }else err='Nieobsługiwany typ VPN';
    let a=cidr(p.local_subnet),b=cidr(p.remote_subnet);if(a&&b&&a.base<=b.end&&b.base<=a.end)err='Sieci lokalna i zdalna nakładają się';
    p.error=err;p.blocked=p.type=='ikev2'&&!!stat('/sys/module/crypto_safexcel');
    if(action=='status'){
        let up=false;try{up=!!bus.call('network.interface.'+p.interface,'status',{}).up;}catch(e){}
        if(p.type=='ikev2')up=up&&!!stat('/tmp/apcontroller-vpn-'+id+'.json');
        p.status=err||((p.blocked?'Przygotowany — IKE czeka na restart':up?'Połączony':'Rozłączony')+(p.enabled=='1'?' · autostart':' · ręczny'));
    }
    push(profiles,p);
});
if(action!='status'){
    for(let p in profiles){
        if((!selected||p.id==selected)&&p.error)die(p.id+': '+p.error+'\n');
        for(let q in profiles){
            if(p.id==q.id)continue;
            if(p.type=='ikev2'&&q.type=='ikev2'&&p.ifid==q.ifid)die('Profile muszą mieć różne identyfikatory XFRM\n');
            if(p.interface==q.interface||p.zone==q.zone)die('Profile muszą mieć różne interfejsy i strefy\n');
            let a=cidr(p.remote_subnet),b=cidr(q.remote_subnet);
            if(a&&b&&a.base<=b.end&&b.base<=a.end&&(p.enabled=='1'||(action=='start'&&p.id==selected))&&q.enabled=='1')die('Aktywne VPN mają nakładające się zdalne podsieci\n');
        }
    }
    if(selected&&!filter(profiles,p=>p.id==selected)[0])die('Nie znaleziono profilu VPN\n');
}
printf('%J\n',profiles);

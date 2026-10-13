import { readfile, stat } from 'fs';
import { cursor } from 'uci';
import { connect } from 'ubus';
let cfg=cursor(), profiles=[], action=ARGV[0]||'status', selected=ARGV[1]||'', bus=connect();
let owned={};for(let line in split(readfile('/etc/multivpn-connect/vpn-managed')||'','\n')){let a=split(trim(line),' ');if(length(a)==4)owned[a[0]]={type:a[1],interface:a[2],zone:a[3]};}
function identifier(v){return type(v)=='string'&&match(v,/^[a-z][a-z0-9_]{0,11}$/);}
function cidr(v){
    let m=match(v||'',/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/);if(!m)return null;
    let n=0;for(let i=1;i<5;i++){let b=int(m[i]);if(b>255)return null;n=n*256+b;}
    let bits=int(m[5]);if(bits<1||bits>32)return null;let size=1;for(let i=bits;i<32;i++)size*=2;let base=int(n/size)*size;
    if(n!=base)return null;return {base:base,end:base+size-1};
}
function path(v,kind){return type(v)=='string'&&match(v,kind=='key'?/^\/etc\/swanctl\/private\/[A-Za-z0-9_.-]+\.pem$/:/^\/etc\/swanctl\/(x509|x509ca)\/[A-Za-z0-9_.-]+\.pem$/)&&stat(v);}
cfg.foreach('multivpn','vpn',p=>{
    let id=p['.name'], err='';p.id=id;
    if(!identifier(id)||!identifier(p.interface)||!identifier(p.zone))err='Nieprawidłowa nazwa profilu, interfejsu lub strefy';
    else if(owned[id]&&owned[id].type!=p.type)err='Nie można zmienić typu istniejącego profilu; dodaj nowy profil';
    else if(!cidr(p.local_subnet)||!cidr(p.remote_subnet))err='Wymagane prawidłowe adresy sieci IPv4 z maską';
    else if(p.mode!='marm-only'&&p.mode!='both')err='Nieprawidłowy kierunek dostępu';
    else if(p.type=='existing'){
        let zone=null;cfg.foreach('firewall','zone',z=>{if(z.name==p.zone)zone=z;});if(cfg.get('network',p.interface)!='interface'||!zone)err='Nie znaleziono istniejącego interfejsu/strefy';else if(index(['sstp','wireguard','xfrm'],cfg.get('network',p.interface,'proto'))<0)err='Istniejący profil musi wskazywać interfejs VPN, nie WAN ani LAN';else if(index(type(zone.network)=='array'?zone.network:split(zone.network||'',' '),p.interface)<0)err='Wybrana strefa nie zawiera interfejsu VPN';
    }else if(p.type=='ikev2'||p.type=='sstp'){
        let zoneExists=false;cfg.foreach('firewall','zone',z=>{if(z.name==p.zone)zoneExists=true;});
        if((cfg.get('network',p.interface)&&(owned[id]||{}).interface!=p.interface)||(zoneExists&&(owned[id]||{}).zone!=p.zone))err='Nie można zastąpić istniejącego interfejsu lub strefy innym profilem VPN';
        else if(owned[id]&&(owned[id].interface!=p.interface||owned[id].zone!=p.zone))err='Po utworzeniu IKE nazwy interfejsu/strefy są stałe; utwórz nowy profil dla innego przypisania';
        else if(!match(p.server||'',/^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$/))err='Nieprawidłowy adres serwera';
        else if(p.type=='sstp'){
            if(!length(p.username||'')||!length(p.password||'')||match(p.username,/\s/)||match(p.password,/[\r\n]/))err='SSTP wymaga loginu i hasła bez znaków nowej linii';
            else if(!match(p.ca||'',/^\/etc\/swanctl\/x509ca\/[A-Za-z0-9_.-]+\.pem$/)||!stat(p.ca))err='Wskaż istniejący plik CA serwera SSTP w /etc/swanctl/x509ca';
        }else if(!match(p.remote_id||'',/^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$/))err='Nieprawidłowa tożsamość serwera';
        else if(!match(p.ifid||'',/^\d+$/)||int(p.ifid)<10||int(p.ifid)>4095)err='Identyfikator XFRM musi być z zakresu 10–4095';
        else if(!path(p.ca,'ca'))err='Brak certyfikatu CA w /etc/swanctl';
        else if(p.auth_mode=='eap-mschapv2'&&(!match(p.username||'',/^[A-Za-z0-9_@.-]{1,128}$/)||!length(p.password||'')||match(p.password,/[\r\n]/)))err='EAP wymaga loginu i hasła';
        else if(p.auth_mode&&p.auth_mode!='pubkey'&&p.auth_mode!='eap-mschapv2')err='Nieobsługiwana metoda uwierzytelnienia IKE';
        else if(p.auth_mode!='eap-mschapv2'&&(!path(p.cert,'cert')||!path(p.key,'key')))err='Brak certyfikatu klienta lub klucza w /etc/swanctl';
        else if(p.ike_mode&&p.ike_mode!='vip'&&p.ike_mode!='site-to-site')err='Nieprawidłowy tryb IKE';
        else if(p.mode=='both'&&p.ike_mode!='site-to-site')err='Dostęp obustronny IKE wymaga trybu site-to-site oraz zgodnej konfiguracji zdalnego serwera';
    }else err='Nieobsługiwany typ VPN';
    let a=cidr(p.local_subnet),b=cidr(p.remote_subnet);if(a&&b&&a.base<=b.end&&b.base<=a.end)err='Sieci lokalna i zdalna nakładają się';
    let localzone=false;cfg.foreach('firewall','zone',z=>{if(z.name==(p.local_zone||'lan'))localzone=true;});if(!localzone||p.local_zone==p.zone)err='Wybierz istniejącą lokalną strefę firewalla inną niż VPN';
    if(p.default_gateway=='1'){
        if(!match(p.gateway_table||'',/^\d+$/)||int(p.gateway_table)<200||int(p.gateway_table)>4095||index([220,253,254,255],int(p.gateway_table))>=0)err='Internet przez VPN wymaga osobnej tabeli routingu 200–4095';
        if(p.type=='existing'&&cfg.get('network',p.interface,'proto')!='sstp')err='Internet przez VPN w istniejącym profilu jest obsługiwany dla SSTP; dla WireGuard użyj natywnego routingu/AllowedIPs';
        if(p.type=='ikev2'&&p.ike_mode=='site-to-site')err='Internet przez VPN w IKE wymaga trybu klient/VIP i zgody zdalnego serwera na 0.0.0.0/0';
    }
    p.error=err;p.blocked=p.type=='ikev2'&&!!stat('/sys/module/crypto_safexcel');
    if(action=='status'){
        let up=false;try{up=!!bus.call('network.interface.'+p.interface,'status',{}).up;}catch(e){}
        if(p.type=='ikev2')up=up&&!!stat('/tmp/apcontroller-vpn-'+id+'.json');
        p.connected=up;p.status=err||((p.blocked?'Przygotowany — IKE czeka na restart':up?'Połączony':'Rozłączony')+(p.enabled=='1'?' · autostart':' · ręczny'));
        delete p.password;
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
            if(p.default_gateway=='1'&&q.default_gateway=='1'&&(p.gateway_table==q.gateway_table||(p.enabled=='1'&&q.enabled=='1')))die('Włącz tylko jedną bramę VPN dla internetu; tabele routingu muszą być różne\n');
            let a=cidr(p.remote_subnet),b=cidr(q.remote_subnet);
            if(a&&b&&a.base<=b.end&&b.base<=a.end&&(p.enabled=='1'||(action=='start'&&p.id==selected))&&q.enabled=='1')die('Aktywne VPN mają nakładające się zdalne podsieci\n');
        }
    }
    if(selected&&!filter(profiles,p=>p.id==selected)[0])die('Nie znaleziono profilu VPN\n');
}
printf('%J\n',profiles);

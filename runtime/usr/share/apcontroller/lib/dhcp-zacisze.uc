#!/usr/bin/ucode
import { readfile } from 'fs';
import { connect, poll, POLLIN } from 'socket';
let auth=json(readfile('/etc/apcontroller/zacisze-api.auth')), deadline=time()+15, bytes=0;
let sock=connect('192.168.88.1',8728,null,3000);
if(!sock)exit(1);
function receive(n) {
    let result='';
    while(length(result)<n) {
        if(time()>deadline || bytes>1048576)die('API response limit');
        let ready=poll(3000,[sock,POLLIN]);
        if(!length(ready||[]))die('API timeout');
        let part=sock.recv(n-length(result));
        if(!length(part||''))die('API connection closed');
        bytes+=length(part);result+=part;
    }
    return result;
}
function word() {
    let first=ord(receive(1)), n=first;
    if(first>=240){n=0;for(let i=0;i<4;i++)n=n*256+ord(receive(1));}
    else if(first>=224){n=first&15;for(let i=0;i<3;i++)n=n*256+ord(receive(1));}
    else if(first>=192){n=first&31;for(let i=0;i<2;i++)n=n*256+ord(receive(1));}
    else if(first>=128)n=(first&63)*256+ord(receive(1));
    if(n>1048576)die('API word limit');
    return n?receive(n):'';
}
function command(words) {
    let request='';
    for(let value in [...words,'']) {
        let n=length(value);
        if(n>=16384)die('API request limit');
        request+=(n<128?sprintf('%c',n):sprintf('%c%c',(n>>8)|128,n&255))+value;
    }
    while(length(request)){let sent=sock.send(request);if(!sent)die('API send failed');request=substr(request,sent);}
    let rows=[];
    while(true) {
        let sentence=[], value;
        while(length(value=word()))push(sentence,value);
        if(sentence[0]=='!trap'||sentence[0]=='!fatal')die('API request rejected');
        if(sentence[0]=='!done')return rows;
        if(sentence[0]=='!re'){
            let row={};for(let v in sentence){let p=index(substr(v,1),'=')+1;if(substr(v,0,1)=='='&&p>0)row[substr(v,1,p-1)]=substr(v,p+1);}push(rows,row);
        }
        if(length(rows)>4096)die('API row limit');
    }
}
try {
    command(['/login','=name='+auth.username,'=password='+auth.password]);
    let leases=command(['/ip/dhcp-server/lease/print','=.proplist=address,mac-address,host-name,status,last-seen,active-address,comment,blocked,disabled']);
    if(length(leases)&&!leases[0]['mac-address'])die('Invalid DHCP response');
    print(sprintf('%J\n',{updated_at:time(),leases:leases}));
    sock.close();
} catch(e) { sock.close();warn('Remote DHCP refresh failed\n');exit(1); }

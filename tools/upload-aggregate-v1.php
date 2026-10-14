<?php
// Encrypted backup envelopes; credentials and raw archives are never logged.
header('Content-Type: application/json');
function fail($code,$message){http_response_code($code);echo json_encode(['error'=>$message]);exit;}
if($_SERVER['REQUEST_METHOD']!=='PUT')fail(405,'PUT required');
$config=@file_get_contents(__DIR__.'/upload.php');
if(!preg_match('/\$TOKEN\s*=\s*["\x27]([^"\x27]+)["\x27]\s*;/',$config?:'', $match))fail(503,'Auth configuration unavailable');
if(!hash_equals('Bearer '.$match[1],$_SERVER['HTTP_AUTHORIZATION']??''))fail(403,'Forbidden');
$name=$_SERVER['HTTP_X_BACKUP_NAME']??'';
if(!preg_match('/^MARM-20[0-9]{6}-[0-9]{6}-[0-9]+\.p7m$/D',$name))fail(400,'Invalid name');
if(($_SERVER['CONTENT_TYPE']??'')!=='application/pkcs7-mime')fail(415,'Encrypted CMS envelope required');
$base=__DIR__.'/encrypted-main';
if(!is_dir($base)&&!@mkdir($base,0700,true))fail(503,'Private backup directory unavailable');
$path=$base.'/'.$name.'.php';$out=@fopen($path,'xb');if(!$out)fail(409,'Cannot create a new backup');
fwrite($out,"<?php http_response_code(404); exit; ?>\n");
$filter=stream_filter_append($out,'convert.base64-encode',STREAM_FILTER_WRITE);
$in=fopen('php://input','rb');$limit=512*1024*1024;$bytes=0;$hash=hash_init('sha256');$valid=true;
while(!feof($in)){$chunk=fread($in,1048576);if($chunk===false){$valid=false;break;}if($bytes===0&&strlen($chunk)&&$chunk[0]!=="\x30"){$valid=false;break;}$bytes+=strlen($chunk);if($bytes>$limit){$valid=false;break;}hash_update($hash,$chunk);if(fwrite($out,$chunk)!==strlen($chunk)){$valid=false;break;}}
fclose($in);stream_filter_remove($filter);fclose($out);@chmod($path,0600);
if(!$bytes||!$valid){@unlink($path);fail(400,'Invalid encrypted backup');}
echo json_encode(['saved'=>$name.'.php','bytes'=>$bytes,'sha256'=>hash_final($hash),'format'=>'CMS DER, base64 after PHP deny header']);

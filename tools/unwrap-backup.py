"""Extract the encrypted CMS envelope from a NAS backup; never handles keys."""
from pathlib import Path
import base64,sys
source,dest=map(Path,sys.argv[1:3])
with source.open('rb') as inp,dest.open('xb') as out:
 assert inp.readline()==b'<?php http_response_code(404); exit; ?>\n','Nieznany format backupu'
 while chunk:=inp.read(4*1024*1024):out.write(base64.b64decode(chunk,validate=True))
print('Wyodrębniono zaszyfrowany plik CMS:',dest)

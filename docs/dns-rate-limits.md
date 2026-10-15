# Limity DNS a pozorna utrata internetu

AdGuard Home może stosować limit zapytań do całego prefiksu IPv4 wskazanego przez `dns.ratelimit_subnet_len_ipv4`. Przy limicie 30 zapytań/s i prefiksie /22 wiele urządzeń współdzieli jeden budżet. Przeglądarki i IoT mogą wtedy obserwować brak odpowiedzi DNS przy nadal działającym WAN.

W diagnozowanej instalacji równoległa seria po 24 zapytania z dwóch adresów dała 24 odpowiedzi na jednym i 2 na drugim. Po ustawieniu prefiksu /32 i zachowaniu limitu 30 na urządzenie obie serie otrzymały po 24 odpowiedzi. To potwierdza naprawę tego ograniczenia, nie wyklucza innych awarii sieci.

Zmiana jest konfiguracją lokalnego serwera DNS, nie automatycznym działaniem pakietu APController. YAML AdGuarda trzeba zachować w backupie routera. Przy edycji pliku należy zatrzymać usługę i poczekać na faktyczne zakończenie procesu, ponieważ aplikacja zapisuje konfigurację podczas zamykania. Po uruchomieniu należy zaczekać na gotowość DNS, a następnie sprawdzić plik i odpowiedzi.

[Dokumentacja AdGuard Home](https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration).

# Skrypty NAS i LuCI

Sekcja „Skrypty z NAS” ma podgląd lokalnych plików, sprawdzenie NAS oraz aktualizację samych plików. Operacja działa w tle, szczegóły są zwijane. Weryfikacja wymaga HTTPS, istniejącego lokalnego tokenu, SHA256 i poprawnej składni sh. Nie aktualizuje env.sh ani nie uruchamia pobranych skryptów. Przy zmianie zachowuje poprzedni plik w /etc/apcontroller/scripts-backup. Pliki użytkownika /scripts/ i prywatne /etc/apcontroller/ są w backupie; kod GUI/backend jest z pakietu.

Synchronizator sync_scripts_from_nas.sh w projekcie legacy-scripts jest niezależny od instalacji APController. Poprawiono wyznaczanie katalogu env.sh, usunięto wypisywanie tokenu, nadpisywanie /etc/config/network, reboot i samodzielną zmianę crona. Nie instaluje pliku z niezgodną sumą. Endpoint index.php odczytuje pliki, nie modyfikuje ich przy GET, wymaga tokenu i udostępnia tylko skrypty .sh, z wyłączeniem env.sh. Istniejący harmonogram nie został zmieniony.

## Migracja synchronizacji Wi-Fi
sync-wireless-smart.sh jest wrapperem APController: na głównym wywołuje sprawdzenie lub publikację i push do wskazanych AP; na końcówce wywołuje pobranie własnej paczki. Dawny skrypt z wczesnym exit i zmianami całej sieci zachowano prywatnie, a jego aktywne zadania cron na przygotowanych AP wyłączono. Mesh/BATMAN wymaga oddzielnego adaptera i sprawdzenia topologii; nie aktywowano dawnych zmian radia/mostów przez usunięcie exit. [Opis synchronizacji i usuwania](Pull-i-stan-docelowy.md).

Autoupdate.sh ma exit przed sysupgrade; nie zastępuje aktualizacji firmware przez Attended Sysupgrade. 99-dhcp-fallback.sh nie jest skanerem link-local i nie należy włączać go na routerze ze statycznym LAN tylko w celu wykrywania 169.254. Make_backup_usb.sh pozostaje wyłączony przez istniejącą blokadę autobackup. Konfiguracja env.sh jest lokalna i nie trafia do publicznych źródeł/pakietów.

Ograniczenie: endpoint PHP chroni pobieranie przez index.php; dostęp do statycznych plików katalogu WWW musi być kontrolowany osobno w serwerze NAS. Nie traktować Bearer w index.php jako zabezpieczenia całego katalogu. SHA256 wykrywa niespójny transfer; źródło skryptów jest zaufanym NAS, nie repozytorium podpisanych APK.

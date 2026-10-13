# Skrypty NAS i LuCI

Sekcja „Skrypty z NAS” ma podgląd lokalnych plików, sprawdzenie NAS oraz aktualizację samych plików. Operacja działa w tle, szczegóły są zwijane. Weryfikacja wymaga HTTPS, istniejącego lokalnego tokenu, SHA256 i poprawnej składni sh. Nie aktualizuje env.sh ani nie uruchamia pobranych skryptów. Przy zmianie zachowuje poprzedni plik w /etc/apcontroller/scripts-backup. Pliki użytkownika /scripts/ i prywatne /etc/apcontroller/ są w backupie; kod GUI/backend jest z pakietu.

Synchronizator sync_scripts_from_nas.sh w projekcie legacy-scripts jest niezależny od instalacji APController. Poprawiono wyznaczanie katalogu env.sh, usunięto wypisywanie tokenu, nadpisywanie /etc/config/network, reboot i samodzielną zmianę crona. Nie instaluje pliku z niezgodną sumą. Endpoint index.php odczytuje pliki, nie modyfikuje ich przy GET, wymaga tokenu i udostępnia tylko skrypty .sh, z wyłączeniem env.sh. Istniejący harmonogram nie został zmieniony.

## Co jeszcze wymaga migracji
sync-wireless-smart.sh ma wczesne exit przed zasadniczą konfiguracją radia/mesh, błędne odwołanie do grep i zależność od katalogu roboczego. Usunięcie exit uruchomiłoby wiele zmian sieci, SSH i radia. Dlatego nie aktywowano tego kodu. Wybrane ustawienia Wi-Fi/VLAN powinny być wysyłane przez istniejące „Zapisz i wyślij konfigurację Wi-Fi”, z przypisaniem do konkretnych AP; kolejny etap to wydzielenie mesh/BATMAN w osobny adapter z podglądem zmian.

Autoupdate.sh ma exit przed sysupgrade; nie zastępuje aktualizacji firmware przez Attended Sysupgrade. 99-dhcp-fallback.sh nie jest skanerem link-local i nie należy włączać go na routerze ze statycznym LAN tylko w celu wykrywania 169.254. Make_backup_usb.sh pozostaje wyłączony przez istniejącą blokadę autobackup. Konfiguracja env.sh jest lokalna i nie trafia do publicznych źródeł/pakietów.

Ograniczenie: endpoint PHP chroni pobieranie przez index.php; dostęp do statycznych plików katalogu WWW musi być kontrolowany osobno w serwerze NAS. Nie traktować Bearer w index.php jako zabezpieczenia całego katalogu. SHA256 wykrywa niespójny transfer; źródło skryptów jest zaufanym NAS, nie repozytorium podpisanych APK.

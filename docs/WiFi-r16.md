# Wi-Fi i skaner — 20261014-r16

Zapisz i wyślij zatwierdza aktywny formularz edycji, potem uruchamia wysyłanie w tle. Wybierz jawnie AP w przypisaniu szablonu. Wysyłanie grupy pokazuje listę urządzeń z możliwością odznaczenia. Sprawdź bez zmian wykonuje walidację na AP bez zastosowania konfiguracji.

Domyślnie VLAN jest odczytywany z wybranego interfejsu głównego routera. Przy ręcznym VLAN wyłącz tę opcję. Istniejący zgodny VLAN na AP jest używany ponownie; różny VLAN powoduje błąd zamiast nadpisania wspólnej sieci. Nieznany lub niejednoznaczny VLAN nie jest zgadywany. Tworzenie nowej sieci nadal wymaga rozpoznanego układu portów oraz uprzednio przygotowanego uplinku/routera. To nie jest uniwersalna konfiguracja wszystkich switchy.

Przyczyną zgłoszonego ERROR dla trzech OpenWrt była ochrona sieci guest, która blokowała także użycie już istniejącego VLAN 12. Sprawdzenie poprawionego agenta na ACPRO1st, PARTER i PIETRO potwierdziło zgodność Guest/VLAN 12 i radia, bez zmian sieci. Przed publikacją sprawdzono składnię JavaScript i shell. Test bez zmian nie dowodzi skuteczności przełączenia dowolnego nowego VLAN-u ani jakości radiowej.

Skaner grupuje wyniki według /24 dla czytelności (nie zmienia maski sieci, także przy skanowaniu /22). Sortowanie: IP, nazwa, ocena. Zielony oznacza 10.48.18.0/24, niebieski pozostałe podsieci, pomarańczowy 169.254. Lista „Zaobserwowano na AP” wskazuje AP widzące jeden host. Wiele AP przy 192.168.88.1 nie oznacza wielu adresów tego hosta. Skan przez VPN nie wykryje dowolnego cichego hosta 169.254: adresy link-local nie są routowane; potrzebny jest odczyt/obserwacja z AP w jego segmencie.

Zapis Wi-Fi w tym wydaniu dotyczy OpenWrt. Omada i UniFi wymagają adapterów kontrolerów; nie wysyłamy do nich poleceń UCI. UniFi pod 127.0.0.1 na komputerze użytkownika nie jest dostępny pod tym samym adresem z routera. MikroTik z radiem/CAPsMAN nie został jeszcze dostarczony do testów zapisu.

Nie zmieniono automatycznie harmonogramu backupu ani topologii BATMAN. Pakiety pozostają w podpisanym repozytorium APK. Payload pakietów nie wymaga ręcznego backupu; konfiguracje, własny dodatkowy skrypt i prywatne klucze wymagają zachowania.

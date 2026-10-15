# Zapasowe połączenie AP przez BATMAN

Pakiet od r29 zawiera materiały wdrożenia w `/usr/share/apcontroller/mesh/`. Nie uruchamia ich na głównym routerze: router bez radia obsługuje zwykły LAN i VLAN-y, a zapasowe 802.11s zestawiają AP. Wdrożenie sieci trzeba dopasować do sprzętu; same skrypty nie tworzą bezpiecznie dowolnej topologii switcha.

## Układ sieci

AP mają wspólny kanał radia zdolnego jednocześnie obsłużyć AP i mesh, szyfrowanie SAE, oddzielny interfejs mesh i `mesh_fwding=0`. `bat0` używa BATMAN_V, BLA jest włączone, bonding wyłączony. Interfejsy usług `bat0.VID` należą do właściwych mostów usług wraz z ich przewodowymi VLAN-ami. Nie wolno tworzyć Guest jako VLAN-u na `bat0.1` ani dodawać `bat0` do mostu, z którego pochodzi jego własny transport.

Przewodowy transport BATMAN na osobnym VLAN-ie łączy zdrowe AP. Ma `auto=0`; monitor dołącza go po uruchomieniu radiowego interfejsu podstawowego. Dzięki temu awaria kabla nie zmienia tożsamości węzła, a zdrowe AP mogą przekazywać między sobą ruch po kablu zamiast przez słabe radio. Główny router nie musi być węzłem BATMAN. Zwykły ruch AP nadal korzysta bezpośrednio z LAN.

Każda usługa wymaga zgodnego VLAN-u na całej drodze i w swoim moście. Dodanie kolejnego SSID do istniejącego interfejsu korzysta z jego zapasu; nowy VLAN wymaga również dołączenia odpowiadającego `bat0.VID`. Po zmianie mostów należy ponownie uruchomić monitor, aby odczytał listę portów.

## Uniwersalne wykrywanie utraty kabla

W switchach ze wspólnym portem CPU jego carrier może pozostać UP po wyjęciu kabla z zewnętrznego portu. Monitor rozpoznaje przewodowe interfejsy mostu zarządzającego z UCI, bez przypisywania gniazda uplink. Wysyła sondę ARP z 0.0.0.0 wyłącznie na przewodowym interfejsie VLAN i sprawdza odpowiedź odbieraną na tym interfejsie. `tcpdump -Q in` wyklucza ramki wychodzące z mesh. Nie bada internetu, więc sama awaria WAN nie uruchamia przełączenia.

Trzy nieudane cykle i istniejący peer mesh powodują odłączenie przewodowych portów zarządzanych mostów oraz transportu BATMAN po kablu. Pozostaje droga radiowa. Dwie poprawne obserwacje przywracają porty i przewodowy transport. UCI portów pozostaje zachowane; zatrzymanie usługi przywraca porty. Błąd narzędzia pomiarowego nie jest uznawany za utratę kabla. Brak odpowiedzi samego routera też może uruchomić przełączenie; mesh nie naprawi awarii routera lub wspólnego switcha całej sieci.

BLA pozostaje włączone również podczas przełączenia. Wygaszanie informacji o wspólnym przewodowym LAN trwa zwykle około minuty; wykrycie awarii dodaje własną zwłokę. To nie jest przełączenie bez utraty pakietów. [Stałe BLA w jądrze](https://raw.githubusercontent.com/torvalds/linux/v6.12/net/batman-adv/main.h), [opis BLA autorów BATMAN](https://downloads.open-mesh.org/batman/papers/batman-adv_v_intro.pdf).

## Narzędzia i kopie

Pliki `uplink-monitor`, `uplink-start`, `uplink-init` kopiowane na AP trafiają odpowiednio do `/etc/apcontroller/batman/` i `/etc/init.d/apcontroller-uplink`. Skrypt init wymaga trybu 755. Gateway odczytywany jest z `network.lan.gateway`, opcjonalnie `APC_GATEWAY` albo konfiguracji pull. Niezbędne są batctl, iw, brctl, ubus, jsonfilter, arping i tcpdump obsługujący kierunek przechwytywania.

Na AP z małą pamięcią flash i APK starter potrafi przygotować tcpdump z bibliotekami w `/tmp/apcontroller-uplink-runtime`, z podpisanych oficjalnych repozytoriów zgodnych z firmware i architekturą AP. Osobny korzeń APK z `--no-scripts` nie zmienia systemowej bazy pakietów ani bibliotek. Biblioteki RAM dostaje tylko wrapper tcpdump. Po ponownym uruchomieniu potrzebny jest dostęp do tych repozytoriów; przy ich niedostępności starter ponawia próbę co minutę. Stan pracy: `/tmp/apcontroller-uplink/status`, log zmian: `logread -e apcontroller-uplink`.

Kod zainstalowanego pakietu na kontrolerze nie wymaga osobnej kopii plików. Kopie agentów i prywatna konfiguracja na AP wymagają zachowania `/etc/apcontroller/`, `/etc/config/network`, `/etc/config/wireless` i `/etc/init.d/apcontroller-uplink` w kopii sysupgrade. Nie należy publikować klucza SAE ani konfiguracji zawierających hasła.

## Weryfikacja

Test powinien obejmować utratę przewodowej drogi przy zachowanym carrier CPU, brak przewodowych portów usług i transportu w stanie mesh, dostęp do routera, duże pakiety, internet/DNS oraz powrót portów po odtworzeniu LAN. Zmiany testowe switcha wymagają niezależnego automatycznego przywrócenia dokładnej poprzedniej listy portów. Nie wolno wykonywać trwałego odcięcia zdalnego AP bez takiego zabezpieczenia.

Włączone BLA i STP ograniczają pętle, ale nie zastępują poprawnego tagowania ani testu topologii. Słaby sygnał między AP oznacza straty i opóźnienia; nie można zagwarantować przepustowości ani stabilności samą konfiguracją. Zmiana wspólnego kanału wymaga ponownego sprawdzenia wszystkich peerów.

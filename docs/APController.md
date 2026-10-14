# APController: sieć, VLAN i publikacja Wi-Fi

Sieć to interfejs na docelowym AP, SSID to nazwa Wi-Fi. Dropdown zawiera interfejsy routera, nazwy szablonów i odczytanych OpenWrt AP. Można wpisać nową nazwę; interfejs routera nie musi istnieć na każdym AP.

VLAN można wybrać lub wpisać (2–4094). Zapisz i wyślij najpierw zatwierdza UCI, następnie wysyła do przypisanych AP. Nowy VLAN/interfejs L2 powstaje na zgodnym OpenWrt w rozpoznanym układzie switch_guest/dev_guest. Nie tworzy to DHCP/firewalla na głównym routerze ani trunku pośredniego switcha. DSA i inne układy wymagają adaptera. Brak docelowej sieci bez VLAN-u jest błędem, nie cichym pominięciem. Kopia AP: /etc/apcontroller/before-send.

Nazwy klientów są aliasami MAC. Grupa łączy hosty i szablony. Zapis szablonu nie publikuje Wi-Fi. Własne skrypty są konfiguracją i pozostają w backupie.

## Inni producenci

Obecny zapis jest wdrożony dla OpenWrt. UniFi/airOS i Omada mają odczyt.

- Omada: możliwy adapter Open API kontrolera po ustaleniu wersji, siteId i endpointów WLAN. Standalone wymaga adaptera modelu. [Dokumentacja TP-Link](https://community.tp-link.com/en/business/forum/topic/590430?moduleId=582).
- UniFi: adapter kontrolera Network zgodny z API jego wersji. Lokalny zapis SSH może zostać nadpisany przez kontroler. [Oficjalne API](https://help.ui.com/hc/en-us/articles/30076656117655-Getting-Started-with-the-Official-UniFi-API).
- airOS: oddzielny adapter firmware, nie ten sam co UniFi/OpenWrt.
- MikroTik: API/SSH RouterOS 6, REST RouterOS 7; rozróżnić wireless, wifi i CAPsMAN. Router bez radia nie nadaje SSID. [REST RouterOS](https://help.mikrotik.com/docs/spaces/ROS/pages/47579162/REST%2BAPI).

## Wskazówki dla kolejnego AI

Nie zgaduj endpointów zapisu ani portów VLAN. Zachowaj konfigurację przed zmianą i sprawdź odczyt po wdrożeniu. Nie publikuj sekretów ani prywatnych logów. Podnieś wersję APK, zweryfikuj podpis i native apk update/policy. Nie nadpisuj wydanej wersji. Nie usuwaj konfiguracji z backupu razem z payloadem APK. Prywatne raporty środowiska są w osobnej paczce projektu poza WWW.

## Skaner urządzeń
Przycisk Skanuj urządzenia wybiera skonfigurowaną prywatną podsieć /22–/30 i wykonuje ograniczony skan ICMP (16 równoległych prób). Wyniki łączy z ARP routera, klientami Wi-Fi i tablicami ARP dostępnych OpenWrt/airOS/UniFi AP. Na AP z tcpdump krótko obserwuje lokalne ARP dla 169.254.0.0/16. Nie nadaje nowych IP ani nie zmienia DHCP/VLAN. Nie skanuje publicznych adresów ani całej przestrzeni link-local przez VPN. Cichego hosta 169.254 bez wpisu ARP i bez transmisji nie zawsze da się wykryć; „bez dzierżawy” może oznaczać adres statyczny. Wynik jest w prywatnym /etc/apcontroller/scanner i backupie konfiguracji.

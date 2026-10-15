# Skanowanie adresów link-local

Zakładka skanowania łączy ICMP skonfigurowanych podsieci, DHCP, ARP i klientów Wi-Fi. Adresy 169.254.0.0/16 nie są routowane przez VPN. Zdalna obserwacja odbywa się przez SSH na dostępnych OpenWrt/airOS/UniFi z tcpdump. Sam zakres skanowania nie tworzy mostu przez VPN.

Od 20261015-r28 kolektor AP nasłuchuje na `any`, aby zobaczyć również dostępne interfejsy radiowe i VLAN-y. Parser rozpoznaje Ethernet oraz Linux cooked capture, dopisuje numer VLAN do źródła i odróżnia sondę adresu (ARP z 0.0.0.0) od zaobserwowanego użycia adresu. Nie oznacza automatycznie każdej sondy jako utraty DHCP. Okno zdalnego nasłuchu wynosi 20 sekund i kończy się wcześniej po 2048 ramkach; lokalne okno trwa 8 sekund. Zajęta sieć może wyczerpać limit wcześniej.

Wiele obserwacji tego samego MAC/IP na różnych AP jest jednym wpisem z wieloma źródłami. Źródło obserwacji nie jest właścicielem adresu. Adres zarządzający urządzenia i link-local na jego innym interfejsie mogą współistnieć. Wynik nie dowodzi awarii DHCP bez sprawdzenia właściwego VLAN-u i konfiguracji urządzenia.

Nie ma gwarancji wykrycia milczących urządzeń, ruchu przełączanego sprzętowo ani urządzeń za Omada, którego CLI nie udostępnia tcpdump. Brak wyniku nie dowodzi braku adresów link-local. Nie wykonujemy zalewowego skanowania ARP całego /16.

Regresje parsera: `sh tests/scanner-apipa.sh` na OpenWrt z ucode; test obejmuje tagowany cooked capture, sondę, ogłoszenie adresu, Ethernet ARP reply, źródłowy IPv4 oraz zwykłą tablicę sąsiadów.

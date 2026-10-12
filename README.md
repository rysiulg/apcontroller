# APController â€” lokalne repozytorium OpenWrt

ĹąrĂłdĹ‚a bazujÄ… na dziaĹ‚ajÄ…cym kontrolerze oraz projekcie [rysiulg/apcontroller](https://github.com/rysiulg/apcontroller). Pakiety sÄ… przeznaczone dla OpenWrt 25.12 i architektury `aarch64_cortex-a53`. Kontroler odpytuje AP przez istniejÄ…cy transport SSH/HTTP; konfiguracjÄ™ Wi-Fi wysyĹ‚a dopiero osobna akcja uĹĽytkownika.

## Instalacja i aktualizacja

Repozytorium na NAS: `\\nas\web\openwrt\ap_repos\apcontroller`.

```sh
wget -O /tmp/install-apcontroller.sh https://nas.marm.pl/openwrt/ap_repos/apcontroller/install.sh
sh /tmp/install-apcontroller.sh
```

Instalator sprawdza sumÄ™ klucza publicznego i podpis indeksu APK, usuwa przypiÄ™cia do starych sum pakietĂłw tego kontrolera oraz dodaje feed HTTPS. Zachowuje istniejÄ…cÄ… konfiguracjÄ™ UCI. Po pierwszej instalacji aktualizacjÄ™ moĹĽna wywoĹ‚aÄ‡:

```sh
apk update
apk add --upgrade luci-apcontroller
```

GĹ‚Ăłwny feed: `https://nas.marm.pl/openwrt/ap_repos/apcontroller/aarch64_cortex-a53/packages.adb`. Pakiety, klucz publiczny i `SHA256SUMS` sÄ… dostÄ™pne obok instalatora. Starsze wydania pozostajÄ… w `releases/`. Repozytorium nie zawiera konfiguracji sieci, haseĹ‚ ani klucza podpisujÄ…cego.

## Nazwy i stan klientĂłw

Kontroler ujednolica `hostname/name`, `ip/ipaddr` i `ssid/wifi`. Nazwy majÄ… kolejnoĹ›Ä‡: wĹ‚asny alias w APController, nazwa statycznej rezerwacji DHCP, nazwa podana przez AP, wskazĂłwki `luci-rpc.getHostHints` gĹ‚Ăłwnego routera. Adresy IP rĂłwnieĹĽ uzupeĹ‚nia gĹ‚Ăłwny router. W API pole `name_source` wskazuje pochodzenie nazwy. Alias moĹĽna dodaÄ‡ w sekcji **Client names** w LuCI.

Brak nazwy DHCP lub aliasu nie pozwala niezawodnie ustaliÄ‡ nazwy urzÄ…dzenia. Losowy adres MAC telefonu moĹĽe wymagaÄ‡ osobnego aliasu dla kaĹĽdej sieci Wi-Fi. Kontroler nie zgaduje nazw na podstawie producenta MAC.

Poprawiono zapis online, przeliczanie wieku kontaktu, odrzucanie odpowiedzi z pustym MAC, pole czasu wymagane przez LuCI i odĹ›wieĹĽanie wskazĂłwek nazw. Klienci z niedostÄ™pnych AP nie sÄ… przedstawiani jako aktualnie poĹ‚Ä…czeni. WywoĹ‚ania crona i pollera wspĂłĹ‚dzielÄ… blokadÄ™ `flock`. SSH zapamiÄ™tuje pierwszy klucz AP w `/etc/apcontroller/known_hosts` i odrzuca jego pĂłĹşniejszÄ… zmianÄ™; nie ignoruje juĹĽ weryfikacji kluczy hosta.

## ĹąrĂłdĹ‚a i budowanie

`source.tar.gz` zawiera kod i skrypty budowania. `apcontroller.bundle` zawiera historiÄ™ Git; moĹĽna wykonaÄ‡ `git clone apcontroller.bundle apcontroller-source`. ZmieĹ„ `VERSION` przed kaĹĽdym kolejnym wydaniem â€” nie nadpisuj opublikowanej wersji innÄ… zawartoĹ›ciÄ….

```sh
APC_BUILD_DIR=/mnt/usbstorage/apcontroller-build sh packaging/build-router.sh /sciezka/do/zrodel
```

Budowanie uĹĽywa peĹ‚nego `apk mkpkg` i `apk mkndx` z `tools/apk.static` (apk-tools 3.0.8). Wersja APK instalowana z OpenWrt nie zawiera tych poleceĹ„ budowania. MoĹĽna wskazaÄ‡ wĹ‚asnÄ… peĹ‚nÄ… wersjÄ™ przez `APK_BUILDER`. NarzÄ™dzie uĹĽyte do tego wydania pochodzi z oficjalnego repozytorium Alpine `edge/main/aarch64`, pakietu `apk-tools-static`.

Klucz prywatny pozostaje w `$APC_BUILD_DIR/.signing/apcontroller-local.pem` z prawami 600, poza serwowanym katalogiem. Zachowaj go do nastÄ™pnych wydaĹ„; nie kopiuj `.signing` na udziaĹ‚ WWW. Wynik budowy jest w `$APC_BUILD_DIR/releases/<VERSION>`.

Po testach kopiuj nowe pliki `.apk`, klucz publiczny i instalator do katalogu repozytorium, a `packages.adb` podmieĹ„ na koĹ„cu. Podpis indeksu i pakietĂłw weryfikuje zainstalowany APK; instalacje nie wymagajÄ… `--allow-untrusted`.

## Ograniczenia

ObsĹ‚uga rĂłĹĽnych producentĂłw nadal zaleĹĽy od ich dostÄ™pnoĹ›ci, poprawnych danych logowania, wykrywania platformy i zgodnoĹ›ci schematu. Ten zestaw poprawek nie implementuje kompletnego zarzÄ…dzania Omada/MikroTik ani automatycznej migracji ich adresĂłw. Szablony agenta push/HTTP wymagajÄ… osobnej integracji z cachem uĹĽywanym przez status RPC. Nie uruchamiaj grupy z opcjÄ… usuwania wszystkich sieci Wi-Fi podczas samego audytu.

Dokumentacja formatu: [apk mkpkg](https://raw.githubusercontent.com/alpinelinux/apk-tools/v3.0.8/doc/apk-mkpkg.8.scd), [apk mkndx](https://raw.githubusercontent.com/alpinelinux/apk-tools/v3.0.8/doc/apk-mkndx.8.scd).

## Wydanie 20261012-r2

Dodano pakiet zbiorczy luci-apcontroller, ktĂłry instaluje backend, LuCI i tĹ‚umaczenie. Dotychczasowe nazwy pakietĂłw pozostajÄ… zgodne z istniejÄ…cymi instalacjami. W LuCI, zakĹ‚adka Ustawienia, znajduje siÄ™ stan pakietĂłw, adres feedu oraz przyciski sprawdzania i uruchamiania aktualizacji. Aktualizacja dziaĹ‚a w tle; przycisk OdĹ›wieĹĽ stan pokazuje jej wynik.

Tabela urzÄ…dzeĹ„ ma mniejsze odstÄ™py i wĹ‚asne przewijanie, bez rozszerzania caĹ‚ej strony. SzerokoĹ›Ä‡ moĹĽna dodatkowo ograniczyÄ‡ wyborem kolumn w Ustawieniach. Czas ostatniego kontaktu w tabeli jest krĂłtki, a dokĹ‚adna data dostÄ™pna w podpowiedzi.

Parser vendor-status.uc obsĹ‚uguje JSON UniFi, status i stacje airOS oraz tekst CLI Omada. Dane sÄ… skĹ‚adane przez serializer JSON; nazwy SSID nie sÄ… wklejane do JSON przez awk. Transport Omada wykonuje wyĹ‚Ä…cznie polecenia odczytu przez sexpect (dokumentacja: https://github.com/clarkwang/sexpect/blob/master/doc/sexpect.adoc). Odpytywanie tych platform nie instaluje agenta na AP. SSH dopuszcza dawny podpis klucza hosta RSA dla zgodnoĹ›ci z Ubiquiti, zachowujÄ…c weryfikacjÄ™ zapamiÄ™tanego klucza.

ZakĹ‚adka Weryfikacja VPN Zacisze wyĹ›wietla prywatny plik /etc/apcontroller/discovery.json. Wpisy importowane do weryfikacji majÄ… wyĹ‚Ä…czone cykliczne odpytywanie i sÄ… oznaczone jako zapis danych, nie stan bieĹĽÄ…cy. Sam VPN na komputerze nie daje routerowi trasy do zdalnej sieci. Plik odkrywania, rzeczywiste prĂłbki i hasĹ‚a nie sÄ… czÄ™Ĺ›ciÄ… repozytorium.

## Wydanie 20261012-r4

Odczyt UniFi/airOS przez SSH oraz Omada przez CLI: klienci, SSID, pasmo, sygnaĹ‚, szybkoĹ›ci, liczniki pakietĂłw i retries, CPU/pamiÄ™Ä‡ oraz dostÄ™pne statystyki radia i interfejsĂłw. Pola zaleĹĽÄ… od firmware urzÄ…dzenia; brak danych nie jest zastÄ™powany wynikiem pomiaru. PeĹ‚ny odczyt znajduje siÄ™ w â€žWiÄ™cej informacji â†’ Dane diagnostyczneâ€ť. Nie sÄ… zmieniane ustawienia radia ani konfiguracja producenta.

Nazwy klientĂłw mogÄ… pochodziÄ‡ z DHCP MikroTika. Opcjonalne prywatne `/etc/apcontroller/zacisze-api.auth` zawiera `username` i `password` konta API tylko do odczytu. Odczyt 192.168.88.1:8728 odbywa siÄ™ wyĹ‚Ä…cznie przy trasie przez sstp-zacisze; dane odĹ›wieĹĽane sÄ… co 5 minut, a bĹ‚Ä…d nie usuwa ostatniego wyniku. Pliku uwierzytelnienia nie wolno publikowaÄ‡ w repozytorium.

LuCI pokazuje tryb istniejÄ…cego tunelu MARMâ€“Zacisze i pozwala przeĹ‚Ä…czyÄ‡ kierunek inicjowania poĹ‚Ä…czeĹ„, jeĹ›li zainstalowano prywatny helper `/usr/sbin/zacisze-vpn-mode`. Pakiet nie instaluje certyfikatĂłw ani konfiguracji VPN.

Aktualizacje sÄ… obsĹ‚ugiwane w natywnym menedĹĽerze APK/LuCI. Repozytorium: `https://nas.marm.pl/openwrt/ap_repos/apcontroller/aarch64_cortex-a53/packages.adb`, zapisane w `/etc/apk/repositories.d/apcontroller.list`. Nie trzeba osobnego panelu aktualizacji w APControllerze. Lista skanu pozostaje prywatnym materiaĹ‚em audytu; interfejs pokazuje wĹ‚aĹ›ciwÄ… listÄ™ AP i bieĹĽÄ…ce dane.

## Wydanie 20261012-r5

Poprawiono dostÄ™pnoĹ›Ä‡ przyciskĂłw wyboru kierunku VPN w LuCI. BieĹĽÄ…cy tryb nie zmienia siÄ™ podczas instalacji ani odĹ›wieĹĽania strony.

## Wydanie 20261012-r6

Lista klientów zawiera sumę połączeń, osobne liczby dla 2,4 / 5 / 6 GHz i liczbę unikalnych MAC. Uwzględnia wyłącznie włączone AP z aktualnym stanem online. Jeden klient na kilku AP może zwiększyć liczbę połączeń, ale pozostaje jednym unikalnym MAC. Natywne podsieci ustawia się w Ustawieniach; pozostałe adresy mają kolor i opis podsieci. Nowe AP są domyślnie włączone; wcześniej wyłączone wpisy zachowują swój stan.

Zakładka Profile VPN zastępuje pojedynczy panel Zacisza. Każdy profil ma nazwę, interfejs, strefę firewalla, podsieci, kierunek dostępu i autostart. Przyciski zapisują konfigurację, łączą lub rozłączają wybrany profil. Kilka tuneli może działać jednocześnie, jeśli ich zdalne podsieci się nie nakładają. Identyfikatory profili, interfejsów i stref: małe litery, cyfry i podkreślenia, maksymalnie 12 znaków, pierwszy znak litera. Interfejsów utworzonych dla IKE nie zmienia się w istniejącym profilu — należy utworzyć nowy profil.

IKEv2 wykorzystuje strongSwan, certyfikat klienta i CA, przydzielony adres VPN oraz osobny interfejs XFRM. Ścieżki wskazują prywatne pliki w /etc/swanctl; pakiet nie dostarcza certyfikatów ani kluczy użytkownika. Ten wariant klienta udostępnia dostęp inicjowany z LAN przez SNAT do przydzielonego adresu VPN. Dostęp inicjowany przez serwer wymaga uzgodnionej konfiguracji site-to-site po jego stronie; nie można uzyskać go samą zmianą opcji klienta. Istniejący SSTP/WireGuard może korzystać z obu kierunków, gdy zdalny router ma trasę powrotną.

Na routerze z załadowanym crypto_safexcel uruchomienie IKE jest blokowane do zaplanowanego restartu, aby nie odtworzyć zdiagnozowanego zawieszenia. Profile można zapisać bez uruchamiania połączenia. Nowe skrypty, konfiguracja APController i prywatne pliki /etc/swanctl trafiają do listy backupu sysupgrade. Kopia zawiera sekrety VPN i powinna pozostać prywatna.

## Wydanie 20261012-r7

Zwężono tabelę profili VPN; typ, interfejs i strefa są dostępne w edycji profilu. Podsieci zachowują czytelny zapis, a tabela przewija się we własnym obszarze przy małej szerokości ekranu.

# APController — utrzymywane wydanie runtime 20261012-r1

Źródła bazują na działającym kontrolerze oraz projekcie [rysiulg/apcontroller](https://github.com/rysiulg/apcontroller). Pakiety są przeznaczone dla OpenWrt 25.12 i architektury `aarch64_cortex-a53`. Kontroler odpytuje AP przez istniejący transport SSH/HTTP; konfigurację Wi-Fi wysyła dopiero osobna akcja użytkownika.

## Instalacja i aktualizacja

```sh
wget -O /tmp/install-apcontroller.sh https://nas.marm.pl/openwrt/ap_repos/apcontroller/install.sh
sh /tmp/install-apcontroller.sh
```

Instalator sprawdza sumę klucza publicznego i podpis indeksu APK, usuwa przypięcia do starych sum pakietów tego kontrolera oraz dodaje feed HTTPS. Zachowuje istniejącą konfigurację UCI. Po pierwszej instalacji aktualizację można wywołać:

```sh
apk update
apk add --upgrade apcontroller luci-app-apcontroller luci-i18n-apcontroller-pl
```

Główny feed: `https://nas.marm.pl/openwrt/ap_repos/apcontroller/aarch64_cortex-a53/packages.adb`. Pakiety, klucz publiczny i `SHA256SUMS` są dostępne obok instalatora. Starsze wydania pozostają w `releases/`. Repozytorium nie zawiera konfiguracji sieci, haseł ani klucza podpisującego.

## Nazwy i stan klientów

Kontroler ujednolica `hostname/name`, `ip/ipaddr` i `ssid/wifi`. Nazwy mają kolejność: własny alias w APController, nazwa statycznej rezerwacji DHCP, nazwa podana przez AP, wskazówki `luci-rpc.getHostHints` głównego routera. Adresy IP również uzupełnia główny router. W API pole `name_source` wskazuje pochodzenie nazwy. Alias można dodać w sekcji **Client names** w LuCI.

Brak nazwy DHCP lub aliasu nie pozwala niezawodnie ustalić nazwy urządzenia. Losowy adres MAC telefonu może wymagać osobnego aliasu dla każdej sieci Wi-Fi. Kontroler nie zgaduje nazw na podstawie producenta MAC.

Poprawiono zapis online, przeliczanie wieku kontaktu, odrzucanie odpowiedzi z pustym MAC, pole czasu wymagane przez LuCI i odświeżanie wskazówek nazw. Klienci z niedostępnych AP nie są przedstawiani jako aktualnie połączeni. Wywołania crona i pollera współdzielą blokadę `flock`. SSH zapamiętuje pierwszy klucz AP w `/etc/apcontroller/known_hosts` i odrzuca jego późniejszą zmianę; nie ignoruje już weryfikacji kluczy hosta.

## Źródła i budowanie

`source.tar.gz` zawiera kod i skrypty budowania. `apcontroller.bundle` zawiera historię Git; można wykonać `git clone apcontroller.bundle apcontroller-source`. Zmień `VERSION` przed każdym kolejnym wydaniem — nie nadpisuj opublikowanej wersji inną zawartością.

```sh
APC_BUILD_DIR=/mnt/usbstorage/apcontroller-build sh packaging/build-router.sh /sciezka/do/zrodel
```

Budowanie używa pełnego `apk mkpkg` i `apk mkndx` z `tools/apk.static` (apk-tools 3.0.8). Wersja APK instalowana z OpenWrt nie zawiera tych poleceń budowania. Można wskazać własną pełną wersję przez `APK_BUILDER`. Narzędzie użyte do tego wydania pochodzi z oficjalnego repozytorium Alpine `edge/main/aarch64`, pakietu `apk-tools-static`.

Klucz prywatny pozostaje w `$APC_BUILD_DIR/.signing/apcontroller-local.pem` z prawami 600, poza serwowanym katalogiem. Zachowaj go do następnych wydań; nie kopiuj `.signing` na udział WWW. Wynik budowy jest w `$APC_BUILD_DIR/releases/<VERSION>`.

Po testach kopiuj nowe pliki `.apk`, klucz publiczny i instalator do katalogu repozytorium, a `packages.adb` podmień na końcu. Podpis indeksu i pakietów weryfikuje zainstalowany APK; instalacje nie wymagają `--allow-untrusted`.

## Ograniczenia

Obsługa różnych producentów nadal zależy od ich dostępności, poprawnych danych logowania, wykrywania platformy i zgodności schematu. Ten zestaw poprawek nie implementuje kompletnego zarządzania Omada/MikroTik ani automatycznej migracji ich adresów. Szablony agenta push/HTTP wymagają osobnej integracji z cachem używanym przez status RPC. Nie uruchamiaj grupy z opcją usuwania wszystkich sieci Wi-Fi podczas samego audytu.

Dokumentacja formatu: [apk mkpkg](https://raw.githubusercontent.com/alpinelinux/apk-tools/v3.0.8/doc/apk-mkpkg.8.scd), [apk mkndx](https://raw.githubusercontent.com/alpinelinux/apk-tools/v3.0.8/doc/apk-mkndx.8.scd).

## Pochodzenie i zakres publikacji

Kod runtime pochodzi z audytowanego, wdrożonego wydania `20261012-r1`; lokalny commit źródłowy: `af734279b1cf4d7cd7b638f639fad993986f1a39`. Nie zmienia automatycznie istniejącego katalogu feed/ ani głównego przepisu SDK projektu. Zachowano dostarczoną licencję GPL v3; metadane przyszłych kompilacji pakietów dopasowano do tej licencji. Już opublikowane pakiety APK pozostają niezmienione. Przed kolejną kompilacją zmień VERSION.

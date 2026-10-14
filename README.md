# APController i MultiVPN Connect — repozytorium APK

OpenWrt 25.12, aarch64_cortex-a53. Autorem pierwotnego APController jest **Cezary Jackiewicz ([obsy](https://github.com/obsy))**, projekt [obsy/apcontroller](https://github.com/obsy/apcontroller). Ta wersja rozwija fork [rysiulg/apcontroller](https://github.com/rysiulg/apcontroller), dodając obsługę danych producentów, pakiety APK, MultiVPN i synchronizację stanu. Zachowano źródłową licencję GPL-3.0 (pełny tekst w LICENSE); metadane naszych nowych paczek wskazują GPL-3.0-only. SSTP zachowuje własną licencję upstream. Pakiety są podpisane lokalnym kluczem; publiczne repozytorium nie zawiera rzeczywistych konfiguracji, haseł ani prywatnych kluczy.

## Instalacja i aktualizacja

Repozytorium: https://nas.marm.pl/openwrt/ap_repos/apcontroller/aarch64_cortex-a53/packages.adb . W LuCI → System → Pakiety → Configure apk należy dodać ten adres do Custom feeds. Instalator zapisuje go w /etc/apk/repositories.d/customfeeds.list i instaluje publiczny klucz po sprawdzeniu jego sumy.

```sh
wget -O /tmp/install-apcontroller.sh https://nas.marm.pl/openwrt/ap_repos/apcontroller/install.sh
sh /tmp/install-apcontroller.sh
apk update
apk add luci-app-multivpn-connect
```

Aktualizacja samych aplikacji: `apk add --upgrade luci-apcontroller luci-app-multivpn-connect`. Nie wymaga budowania ani wgrywania firmware. Pakiety APController to apcontroller, luci-app-apcontroller, luci-i18n-apcontroller-pl i alias luci-apcontroller. VPN jest oddzielony w multivpn-connect oraz luci-app-multivpn-connect. Repozytorium indeksuje także dokładny działający lokalny sstp-client 1.0.20-r3, aby dotychczasowe przypięcie jego sumy pozostało rozwiązywalne.

## APController

Nazwy klientów są aliasami MAC, mającymi pierwszeństwo przed DHCP i nazwami AP. Grupę AP tworzą hosty i szablony Wi-Fi do wysłania. Odczyt UniFi/airOS i Omada jest obsługiwany; zapis konfiguracji jest dostępny dla OpenWrt. Omada SSH udostępnia CLI, więc skrypty powłoki OpenWrt nie są wysyłane do Omada.

Wi-Fi pokazuje oddzielnie planowane przypisania i AP, na których odczytano SSID. Domyślnie zapis publikuje pełny stan dla przypisanych OpenWrt; końcówki pobierają go po starcie i co 2 minuty. Zapisz i wyślij dodatkowo wywołuje pobranie od razu. Zapisz i sprawdź nie publikuje projektu konfiguracji. Dodanie, zmiana SSID i usunięcie są uzgadniane według trwałych identyfikatorów, bez kasowania niezależnych sieci AP, mesh i stacji. Opcjonalne pole VLAN przygotowuje sieć na OpenWrt w rozpoznanym układzie switch_guest/dev_guest; przy innym układzie wymagany jest dodatkowy skrypt. Nowy VLAN używa jednej przewodowej ścieżki CPU/LAN oraz STP, żeby nie dublować ścieżek przez BATMAN lub drugi port CPU. Agent zachowuje kopię network/wireless i dopisuje zmieniane konfiguracje do sysupgrade.conf. Nie zastępuje sieci zarządzającej.

Skrypty do urządzeń znajdują się w /usr/share/apcontroller/scripts; akcja Wykonaj skrypt dotyczy powłoki zgodnego AP. Dodatkowy skrypt jest wykonywany przez grupę tylko po włączeniu odpowiedniej opcji. Publiczny klucz SSH można dopisać oddzielnym przyciskiem na OpenWrt/root; prywatnego klucza nie wysyła się na AP.

## MultiVPN Connect

Menu Usługi → MultiVPN Connect. Nowe IKE/SSTP tworzą natywny interfejs i strefę firewalla. Istniejący SSTP/WireGuard można powiązać z profilem. Wybiera się lokalną podsieć i strefę; nazwy nowego interfejsu i strefy wpisuje się w odpowiednie pola. Domyślnie dostęp inicjuje tylko lokalna sieć. Odpowiedzi na jej połączenia są dozwolone. Dostęp obustronny wymaga także tras/reguł na zdalnym routerze.

IKE klient/VIP stosuje SNAT do adresu przydzielonego przez serwer. Tryb site-to-site negocjuje całe podsieci bez takiego SNAT i wymaga zgodnych selektorów/certyfikatów na drugim końcu. Różne zdalne podsieci mogą działać równocześnie.

Internet IPv4 przez VPN jest opcją domyślnie wyłączoną. Obejmuje wskazaną lokalną podsieć, zachowuje trasy lokalne, wymaga internetu/NAT na zdalnym końcu, a w IKE selektora 0.0.0.0/0. DNS routera i IPv6 zachowują dotychczasową drogę. Po utracie tunelu wraca WAN; nie jest to kill switch. Opcja dla istniejącego interfejsu obsługuje SSTP; pełny tunel WireGuard ustawia się natywnie, wraz z AllowedIPs.

Uruchamianie, zatrzymywanie i zastosowanie konfiguracji mają raport z czasem, kodem wyniku i stanem po akcji. Zadanie działa poza pojedynczym wywołaniem RPC. LuCI zatwierdza wyłącznie konfigurację danego modułu, zamiast uruchamiać globalne uci/apply.

## Firmware i kopie

Attended Sysupgrade buduje cały obraz; lokalny wpis APK nie przekazuje automatycznie repozytorium i klucza serwerowi budującemu. Serwer musi dopuścić dodatkowy feed. W tym wydaniu integracja LuCI ASU usuwa nasze pakiety z żądania serwera i dodaje skrypt ich ponownej instalacji po pierwszym uruchomieniu. Skrypt pobiera publiczny klucz, sprawdza przypiętą sumę i instaluje podpisane APK. Wymaga działającego WAN i repozytorium NAS; zachowaj prywatną konfigurację/certyfikaty. Obejmuje wyłącznie OpenWrt 25.12 i aarch64_cortex-a53. Nie wgrywa firmware ani nie restartuje routera przy aktualizacji samych aplikacji. Nie usuwa się pakietów z world tylko po to, żeby ukryć błąd. Prywatne UCI, certyfikaty, uprawnienia i skrypty lokalne wymagają kopii niezależnie od formy pakietu.

## Budowanie

```sh
APC_BUILD_DIR=/mnt/usbstorage/apcontroller-build sh packaging/build-router.sh /sciezka/do/zrodel
```

Budowanie używa pełnych apk mkpkg/mkndx. Klucz prywatny w .signing pozostaje poza katalogiem WWW. Pakiety kopiuj przed atomową podmianą packages.adb; nie nadpisuj opublikowanej wersji inną zawartością. Źródła i historia są w source.tar.gz i apcontroller.bundle. Opis upstream/lokalnego SSTP jest w multivpn/sstp-source.

## Pobieranie przez AP

[Opis zapisu, push, pobierania i usuwania sieci](docs/Pull-i-stan-docelowy.md). Klucze klientów są ograniczone do odczytu ich własnych paczek. Stare harmonogramy synchronizacji i automatycznego firmware na AP zastępuje nowy klient. Prywatne paczki konfiguracji, hasła Wi-Fi i klucze pozostają poza publicznym repozytorium.

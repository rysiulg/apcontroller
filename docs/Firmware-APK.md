# Budowanie, instalowanie i aktualizacja firmware

packaging/build-router.sh tworzy podpisane APK obu projektów i packages.adb. Dokumentacja docs jest w źródłach i katalogu wydania. Prywatny klucz .signing pozostaje poza WWW.

Repo: https://nas.marm.pl/openwrt/ap_repos/apcontroller/aarch64_cortex-a53/packages.adb. Router ma wpis w /etc/apk/repositories.d/customfeeds.list i publiczny klucz /etc/apk/keys/apcontroller-local.pem. Instalacja: apk update, następnie apk add luci-apcontroller luci-app-multivpn-connect. Aktualizacja aplikacji: apk add --upgrade luci-apcontroller luci-app-multivpn-connect.

## Cały OpenWrt

Custom feed routera nie jest automatycznie repozytorium chmurowego buildera ASU. Obecna integracja ASU pomija własne pakiety podczas budowy i instaluje je z podpisanego repo po pierwszym starcie nowego obrazu. Wymaga WAN i zachowania konfiguracji. Pierwszego startu po flashowaniu nie przetestowano; pakiety nie są wbudowane w ten obraz ASU.

Aby mieć je już w obrazie, użyj własnego ImageBuildera OpenWrt 25.12 dla mediatek/filogic, aarch64_cortex-a53:

1. Dodaj powyższy adres do pliku `repositories` ImageBuildera (APK; nie repositories.conf OPKG).
2. Skopiuj zweryfikowany publiczny klucz repo do `keys/` ImageBuildera.
3. W drzewie FILES dodaj `etc/apk/keys/apcontroller-local.pem` i `etc/apk/repositories.d/customfeeds.list`, aby wynikowy router również miał repo.
4. Sprawdź `make manifest PROFILE="wlasciwy_profil" PACKAGES="luci-apcontroller luci-app-multivpn-connect sstp-client"`, następnie `make image` z tym profilem, pełną potrzebną listą pakietów i `FILES="sciezka/files"`.

Te pakiety są dodatkiem do domyślnego zestawu; nie odtwarza to automatycznie wszystkich innych aplikacji działającego routera. Pełnego obrazu ImageBuilder nie budowano ani nie wgrywano. [Makefile OpenWrt ImageBuilder](https://github.com/openwrt/openwrt/blob/openwrt-25.12/target/imagebuilder/files/Makefile).

Backup zachowuje UCI, certyfikaty, prywatne klucze, skrypty użytkownika i uzasadnione nadpisania systemowe. Payload APK nie jest ręcznie dopisywany do listy. Nie odtwarzaj starego world/kernel/libc na nowym firmware. Prywatne raporty środowiska są w oddzielnej paczce do budowania poza WWW.

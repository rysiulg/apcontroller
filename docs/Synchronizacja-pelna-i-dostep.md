# Pełna synchronizacja i przygotowanie OpenWrt - r26

Kontroler przechowuje wersjonowany stan docelowy dla każdego AP. Włączenie `pull_sync` uruchamia pobieranie po starcie oraz co 120 sekund. Zapis w LuCI publikuje wersję; Zapisz i wyślij dodatkowo wywołuje jej pobranie. Zadanie kontrolera co dwie minuty odświeża paczki i przygotowuje dostępne końcówki, dzięki czemu także zmiana hasła głównego jest uwzględniana.

`pull_full_sync=1` oznacza, że wszystkie sekcje wireless typu wifi-iface/mode=ap mają odpowiadać przypisanym szablonom. Usuwa także nieoznaczone pozostałości. Domyślnie nowy AP ma tę opcję wyłączoną. Zmiana nazwy szablonu zachowuje tożsamość id/pasmo/radio; po dodaniu i usunięciu szablonu AP odpowiednio tworzy i usuwa sieci. Sekcje mesh i sta, kanały radiów, adres zarządzania, trunki i firewall nie są kopiowane z głównego. Nieobsługiwane VLAN-y są odrzucane przed zmianą.

Przed przejęciem klient zapisuje network/wireless/system, a kontroler ich prywatną kopię w `/etc/apcontroller/inventory/<id>/`. Edycja AP pokazuje odczytaną listę Wi-Fi i sieci bez haseł. Odczyt nie importuje automatycznie każdej zastanej, być może przestarzałej sieci jako szablonu dla wszystkich AP. Administrator wybiera stan docelowy i przypisania. W razie nieudanej aplikacji lub braku odpowiedzi ICMP głównego klient przywraca network/wireless. Nie jest to gwarancja odporności na awarię zasilania w trakcie zapisu.

## Dostęp i hasło

`ssh_auth_mode=auto` generuje klucz Ed25519 kontrolera, wysyła publiczną część przez dotychczasowy dostęp, sprawdza logowanie BatchMode z wyłączonym dobieraniem innych kluczy i dopiero wtedy ustawia usekeyfile. Prywatny klucz pozostaje na kontrolerze. Tryb password ustawia używanie hasła; automatyzacja nie wyłącza globalnie logowania hasłem w Dropbear. Przycisk przygotowania klucza nie wymaga wklejania. AP używa odrębnego klucza RSA do pobierania, z przypiętym kluczem hosta głównego i forced-command pozwalającym wyłącznie odczytać własną paczkę.

`sync_root_password=1` kopiuje hash crypt root z głównego do AP, dopiero gdy potwierdzono dostęp kluczem. Wspierane hashe: $1$, $5$, $6$. Nie pobiera jawnego hasła i nie zapisuje go w skryptach. Opcja domyślnie wyłączona. Konto root i pozostałe pola shadow są zachowane. `sync_hostname=1` ustawia nazwę hosta zgodnie z managed_hostname lub nazwą AP. Prywatne kopie, hashe, konfiguracje Wi-Fi i klucze są chronione prawami oraz backupem stanu; nie wchodzą do źródeł ani publicznego APK.

## Roaming i skanowanie

Pola Wi-Fi obejmują 802.11r/k/v, mobility_domain, FT over DS i lokalne generowanie FT-PSK. Domyślnie roaming jest wyłączony. Adapter w tym wydaniu dopuszcza FT tylko z WPA2-PSK. Wymaga odpowiedniego hostapd i zgodnych klientów. Dla starszych IoT pozostawić wyłączone.

Skaner odczytuje sąsiadów i słucha ARP/IPv4 169.254.0.0/16 przez 8 sekund na głównym LAN oraz dostępnych AP z tcpdump. Nie odpytuje 65534 adresów przez ping. Milczący host i AP bez tcpdump mogą nie ujawnić adresu. APIPA nie jest pula DHCP routera i nie przechodzi przez VPN warstwy 3. Dla zdalnego LAN potrzebna jest obserwacja lokalnego AP. Nie sam brak dzierżawy, lecz zaobserwowany adres link-local jest oznaczany jako fallback.

## Weryfikacja

Test izolowany sprawdza zmianę Guest na Guest1 w istniejącej sekcji, usuwanie duplikatu, usunięcie szablonu z zachowaniem mesh/sta, odrzucanie niezgodnego FT przed zapisem, kompilację ucode oraz składnię shell/JS. Wdrożenie lokalne powinno dodatkowo potwierdzić zgodność wersji po dwóch pobraniach, działanie SSH w obu kierunkach, zgodność hashy bez ujawniania wartości i zachowanie dostępu zarządzającego. Failover Batman wymaga odrębnego projektu transportu i testu utraty uplinku; włączenie synchronizacji Wi-Fi go nie uruchamia.

Źródła opcji: https://openwrt.org/docs/guide-user/network/wifi/basic i https://openwrt.org/docs/guide-user/network/wifi/mesh/batman

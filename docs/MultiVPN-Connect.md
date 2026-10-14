# MultiVPN Connect

Pakiety multivpn-connect i luci-app-multivpn-connect są oddzielone od APController. Nowe IKE/SSTP tworzą natywne interfejsy i strefy firewall, istniejące SSTP/WireGuard są wiązane z profilem. Aktywne zdalne podsieci nie mogą się nakładać.

Domyślnie lokalna sieć inicjuje ruch; dostęp odwrotny jest oddzielnym wyborem. IKE klient/VIP wymaga konfiguracji site-to-site na zdalnym routerze dla inicjowania ze zdalnej sieci. Default gateway jest niezależną opcją profilu, domyślnie wyłączoną. Wymaga zdalnego NAT i selektora 0.0.0.0/0 w IKE. IPv6 i DNS routera zachowują drogę, po rozłączeniu możliwy jest WAN; nie jest to kill switch.

Start/stop/apply zapisują raport czasu, wyniku i stanu. Transport/SA nie gwarantuje osiągalności zdalnego LAN; sprawdź drogę powrotną i konkretny host. Certyfikaty, klucze i UCI wymagają prywatnego backupu niezależnie od formy APK.

Ponowne Połącz zachowuje istniejący IKE/CHILD_SA przy niezmienionej konfiguracji. Zmiana konfiguracji IKE wymaga ponownego zestawienia tylko wybranego profilu. Interfejs XFRM musi być gotowy przed negocjacją. Odrzucenie duplikatu nie może usuwać działającej sesji.

LuCI odświeża status co 5 sekund. Okno operacji pokazuje krótki wynik, a pełny log znajduje się pod Szczegóły i log. Poprawny zapis edycji zatwierdza własne UCI i zamyka okno; błędna walidacja pozostawia formularz do poprawienia.

## Telefon przez MARM do innych lokalizacji
Opcja „Dostęp z VPN telefonu do tej lokalizacji” domyślnie pozwala klientom z adresowanych interfejsów strefy vpn inicjować ruch do zdalnej podsieci profilu. Pule są wyznaczane z UCI network/firewall (na MARM: WireGuard 192.168.254.0/24, IKE 192.168.253.0/24), bez zezwolenia na ruch z innych stref. Dla IKE/VIP źródło jest zamieniane na przydzielony adres klienta, dla site-to-site na lokalny adres routera z wybranej podsieci; dla SSTP jest maskowane adresem tunelu. Oddzielne reguły NAT powstają po zestawieniu i są odtwarzane przez hook IKE/iface. Nie zmienia to kierunku dostępu zdalna sieć → MARM ani prawa inicjowania połączeń do telefonu.

Na telefonie w WireGuard AllowedIPs muszą obejmować zdalne sieci albo 0.0.0.0/0. Dla IKE telefon musi kierować te adresy do MARM, a selektory jego sesji muszą je obejmować (standardowy pełny tunel). Ta opcja daje dostęp do zdalnej podsieci, nie przełącza internetu telefonu na zdalny serwer. WMazur i Gvarant nadal mają konflikt tej samej sieci 10.48.17.0/24. Odtworzenie pakietu przy firmware nie zastępuje backupu prywatnego UCI i certyfikatów.

Dla istniejącego serwera MARM w common.conf (ikev2clients / XFRM 3) zastosowanie profili dodaje podsieci z dostępem telefonu do local_ts. Pierwotny selektor jest w prywatnym /etc/multivpn-connect/ike-server-local-ts.base. Nowe selektory wymagają ponownego połączenia telefonu. Ładowanie IKE korzysta z całego swanctl.conf, aby nie usuwać serwera IKE przy uruchamianiu profilu klienckiego. Plik common.conf jest objęty backupem /etc/swanctl/.

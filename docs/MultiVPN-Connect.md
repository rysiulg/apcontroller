# MultiVPN Connect

Pakiety multivpn-connect i luci-app-multivpn-connect są oddzielone od APController. Nowe IKE/SSTP tworzą natywne interfejsy i strefy firewall, istniejące SSTP/WireGuard są wiązane z profilem. Aktywne zdalne podsieci nie mogą się nakładać.

Domyślnie lokalna sieć inicjuje ruch; dostęp odwrotny jest oddzielnym wyborem. IKE klient/VIP wymaga konfiguracji site-to-site na zdalnym routerze dla inicjowania ze zdalnej sieci. Default gateway jest niezależną opcją profilu, domyślnie wyłączoną. Wymaga zdalnego NAT i selektora 0.0.0.0/0 w IKE. IPv6 i DNS routera zachowują drogę, po rozłączeniu możliwy jest WAN; nie jest to kill switch.

Start/stop/apply zapisują raport czasu, wyniku i stanu. Transport/SA nie gwarantuje osiągalności zdalnego LAN; sprawdź drogę powrotną i konkretny host. Certyfikaty, klucze i UCI wymagają prywatnego backupu niezależnie od formy APK.

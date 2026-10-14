# Skanowanie — r20

Skaner jest osobną podzakładką APController → Skanowanie. Nie wyświetla się nad wszystkimi zakładkami. Przy zapisie/resetowaniu formularza jest renderowany ponownie jako sekcja mapy, bez tworzenia dodatkowych sekcji UCI.

Grupowanie i etykiety korzystają z rzeczywistych masek znanych z interfejsów, profili MultiVPN i zakresów skanowania. Zacisze 192.168.88.0/22 obejmuje .88–.91; 192.168.32.0/22 obejmuje .32–.35. Podział na /24 nie zastępuje już tych masek. Nieznana maska jest oznaczona jawnie.

192.168.32.0/22 nakłada się w MARM i Zaciszu. Ta zmiana poprawia prezentację, nie tworzy nowej trasy VPN do nakładającej się podsieci i nie zmienia VLAN-ów.

Wysyłanie Wi-Fi i dodatkowych skryptów powłoki pozostaje dostępne dla zgodnych OpenWrt. Operator wybiera konkretne AP lub grupę, a wysyłanie grupy pokazuje urządzenia docelowe. Omada i UniFi mają odczyt danych; zapis przez kontrolery nie jest jeszcze wdrożony. Skrypty OpenWrt/UCI nie są zgodne z CLI Omada ani z natywnymi urządzeniami UniFi. OpenWrt zainstalowany na sprzęcie UniFi jest obsługiwany jako OpenWrt.

# SSTP 1.0.20-r3 — lokalny pakiet i źródła

Repozytorium zawiera dokładny podpisany APK 1.0.20-r3 już działający na routerze. Nie przebudowuje ani nie zamienia binariów SSTP podczas aktualizacji APController. Włączenie tego pliku do indeksu pozwala APK rozwiązać przypięcie oryginalnej sumy w world.

Pełny kod upstream GPL-2.0-or-later: https://gitlab.com/sstp-project/sstp-client/ . Archiwum Debian sstp-client_1.0.20.orig.tar.bz2 pobrano z https://deb.debian.org/debian/pool/main/s/sstp-client/sstp-client_1.0.20.orig.tar.bz2 i sprawdzono MD5 cb430476adaca2a7d767c0f01dc302f9. Dołączone pliki C są zachowanymi źródłami upstream; sstp-proto-fixed.sh jest lokalną konfiguracją netifd. To nie jest kompletna recepta odtworzenia wcześniejszej naprawy binarnej r3. Dla nowej kompilacji potrzebny jest SDK OpenWrt i odtworzenie zmian z działającego pakietu.

Weryfikacja certyfikatu serwera pozostaje obowiązkowa. Nie stosuj --cert-warn. Pakiet nie zawiera prywatnych certyfikatów ani rzeczywistych haseł.

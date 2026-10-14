# Zadania RPC — r18

Sprawdzenie z otwartego formularza Wi-Fi w r17 zapisywało dane i wykonywało zadanie, ale file.exec przez ubus czekał do timeoutu 30 s. Test bezpośredni `ubus call file exec` odtworzył błąd; zwykłe uruchomienie przez SSH nie wykazywało go.

Uruchamianie workerów zmieniono na BusyBox start-stop-daemon w trybie tła. Test tego samego wywołania zakończył się kodem 0 po 0,01 s, a wynik zadania jest odczytywany osobno. Ta zmiana obejmuje Wi-Fi, skanowanie, pobieranie skryptów i MultiVPN. Nie zmienia negocjacji VPN ani konfiguracji radiowej.

Stary sync-wireless-smart.sh zastąpiono na NAS i głównym routerze wrapperem mechanizmu APController. Wymaga jawnej grupy, trybu check/verbose i listy urządzeń; bez argumentów nie zmienia sieci. Stary skrypt był zatrzymany przez exit i mieszał aktualizacje, radia, klucze oraz BATMAN. Oryginały pozostają prywatnie do analizy i odtworzenia. Wrapper w /scripts jest własnym plikiem i pozostaje objęty backupem /scripts; program wykonywania jest payloadem pakietu.

# r31: ograniczenie dodatkowych ścieżek BATMAN

Monitor domyślnie nie uruchamia przewodowego transportu BATMAN `bat0_eth`/`br-bat`. Zwykły Ethernet pozostaje ścieżką podstawową usług, a `mesh0` drogą zapasową między AP. BLA pozostaje włączone. Jawny eksperymentalny opt-in starego transportu: `network.bat0_eth.apcontroller_wired_transport=1`; bez tej opcji transport przewodowy BATMAN jest wyłączony.

Motywacja: po wcześniejszych testach pojawiły się doniesienia o utracie internetu i historyczne komunikaty routera o powrocie ramek z własnym MAC. Dodatkowy transport przewodowy zwiększa liczbę równoległych ścieżek. Jego wyłączenie upraszcza topologię; samo w sobie nie dowodzi usunięcia wszystkich możliwych pętli lub problemów radiowych.

Kontrolowana izolacja przewodowego VLAN LAN na jednym AP, z zachowaniem CPU UP i niezależnym przywróceniem po 180 s, potwierdziła przejście na mesh i dostęp do bramy/internetu/DNS. Próbka wykazała jednak straty: LAN 1/10, duże pakiety 2/5, internet 1/3. Nie jest to potwierdzenie stabilnego, gotowego do krytycznych zastosowań failoveru. Potrzebne są dalsze pomiary radiowe oraz fizyczne testy kabli po jednym AP.

Zmieniony agent należy wdrożyć również na końcówkach; aktualizacja samego pakietu kontrolera udostępnia materiał źródłowy, ale nie jest dowodem zgodności agentów działających na wszystkich AP. Lokalne pliki agentów i konfiguracja sieci końcówek wymagają zachowania w ich backupie.

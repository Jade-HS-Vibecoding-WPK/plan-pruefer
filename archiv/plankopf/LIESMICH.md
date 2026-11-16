# Archiv: Plankopf-Prüfung

Das war der erste Testlauf des Planprüfers (Stufe 1). Er prüfte, ob acht Angaben im Plankopf vorhanden sind:
Projektname, Projektort (Straße, PLZ, Ort), Bauherr, Maßstab, Datum, Planer, Planbezeichnung, Plannummer.

Wir haben ihn aus der App genommen, weil Planköpfe zu individuell aufgebaut sind. Der Code bleibt hier als Vorlage erhalten,
denn er zeigt, wie man Beschriftung und Wert im PDF einander zuordnet (rechts daneben oder darunter) und wie man Synonyme behandelt.

- `plankopf-pruefung.ps1` – die Prüfung (eigenständig lauffähig)
- `testlauf.ps1` – prüft alle Pläne in `testplaene/` und vergleicht mit der Erwartung

Stand beim Archivieren: 11 von 11 testbaren Plänen richtig erkannt (der Plan ohne Nordpfeil ist ausgenommen).

Aufruf aus dem Projektordner:

    powershell -File archiv\plankopf\testlauf.ps1

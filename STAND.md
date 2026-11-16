# Stand und nächste Schritte

Stand: Ende Montag, 16.11.2026 (Tag 1 von 5). Der Zeitplan steht in [PLAN.md](PLAN.md), die Prüfpunkte in [PRUEFKATALOG.md](PRUEFKATALOG.md).

## Was heute fertig geworden ist

- **Web-App läuft** (PowerShell, kein Python/Node nötig). Start per `Planpruefer-starten.cmd`, Adresse `http://localhost:8080`.
- **Planungsphase wählen** vor dem Upload: Entwurfsplanung oder Werkplanung (wird bei jedem Besuch neu gefragt, nicht gespeichert).
- **Prüfpunkte gebaut:**
  - **A4 Raumflächen**: Zahl mit m² zählt, ob "NGF:" davorsteht oder nicht.
  - **A3 Raumbezeichnungen**: jede Fläche braucht einen Raumnamen.
  - **A3K Raum ohne Name und Fläche (KI)**: gebaut, aber **noch nicht mit der echten KI getestet**.
- **KI-Baustein** für Google Gemini (kostenlos), standardmäßig aus, nur mit ausdrücklichem Einschalten. Liegt allein in `pruefung/ki/gemini.ps1` und lässt sich später austauschen.
- **Testlauf**: `powershell -File pruefung\testlauf.ps1`, aktuell 13 von 13 richtig (ohne echten KI-Aufruf).
- Plankopf-Prüfung war ein Testlauf und liegt im Archiv (`archiv/plankopf/`). Hochschul-Checklisten (Entwurf, Werk) sind ausgewertet und im Prüfkatalog eingearbeitet.

## Eure Aufgaben für morgen

1. **Server neu starten**, damit alles Neue gilt: das schwarze Server-Fenster schließen und `Planpruefer-starten.cmd` doppelklicken. (Der Server läuft zurzeit noch mit altem Stand.)
2. **KI einrichten** (siehe README, Abschnitt "KI-Prüfung einrichten"):
   - Schlüssel auf [aistudio.google.com/apikey](https://aistudio.google.com/apikey) erstellen
   - in die Datei `schluessel.txt` im Projektordner einfügen (die Datei ist schon angelegt, nur die Platzhalterzeile ersetzen)
   - den Schlüssel **nicht** im Chat teilen
3. **Testplan `04_A3K_fehler.pdf`** in `testplaene/entwurf/` ablegen: bei **einem** Raum ist der ganze Stempel gelöscht (Name und Fläche), sonst alles in Ordnung.
4. Optional, hilft den Tests: einen Plan, bei dem nur **ein** Raum keine Fläche hat, und einen Plan mit einem **anderen Stempel-Layout**.

## Danach (mit Claude)

1. **KI live testen** mit `04_A3K_fehler.pdf`. Wenn die KI daneben liegt, Anfrage oder Modell anpassen. Ist das Modell im kostenlosen Zugang nicht erlaubt, in `schluessel.txt` eine Zeile `modell=...` setzen.
2. **A7 Höhenangaben** bauen. Der Plan `01_A4_fehler.pdf` hat versehentlich auch keine Höhenangabe ±0,00 und gilt dafür als Fehlerfall (im Testlauf schon als bekannter Zusatzfehler eingetragen).
3. Weitere Punkte in dieser Reihenfolge: A6 Schnittlinien, A1 Nordpfeil (KI), A8 Eingangspfeil (KI), A5 Flächenplausibilität, A2 Bemaßung. Dazu A9 bis A11 für die Werkplanung.
4. Werkplanung ergänzen: A4 verlangt dort zusätzlich Umfang, Raumhöhe und Bodenbelag.
5. Offene Entscheidung: Soll eine einfache Prüfung "Plankopf vorhanden" (A12) zurück? Beide Hochschul-Checklisten fordern einen Plankopf.

## Wichtig zu wissen

- **Nichts mit dem Schlüssel committen.** `schluessel.txt` steht in der `.gitignore`. Testpläne (`testplaene/`, `archiv/testplaene/`) und Hochschul-Unterlagen (`unterlagen/`) gehen ebenfalls nicht zu GitHub.
- **KI-Funde sind Hinweise**, keine sicheren Urteile. Bei eingeschalteter KI geht der Plan an Google, nur eigene, unkritische Pläne verwenden.
- **Grenze von A3:** Ein Raum ohne Name und ohne Fläche steht nicht im PDF-Text. Das fängt nur die KI (A3K).
- Zeitplan: Donnerstag **12 Uhr Freeze**, danach nur noch Poster und Demo. Wenn die Zeit knapp wird, streichen wir zuerst die Markierungen im Plan (siehe PLAN.md).

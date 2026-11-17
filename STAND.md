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

## Dienstag, 17.11.: dazugekommen

- **A7 Höhenangaben** (Fußbodenhöhe, ohne KI) gebaut.
- **A7K Höhenangabe an Raumebenen (KI)** gebaut, ebenfalls noch nicht live getestet. Entschieden: Pflicht nur dort, wo die Ebene wechselt.
- Testlauf: 17 von 17 richtig (ohne echten KI-Aufruf).
- **KI läuft:** Schlüssel in `schluessel.env` wird erkannt (die App liest `schluessel.txt`, `schluessel.env` und `.env`, alle in der `.gitignore`). Die Verbindung zu Gemini funktioniert, die KI liest Raumnamen und Flächen im Musterplan fehlerfrei.
- **Beim ersten Live-Test gefunden und behoben:** Die KI-Antwort kam in einem unbekannten Feld (`steps`), die App wich auf einen zweiten Weg aus, und die KI hielt sich nicht an die vorgegebene Struktur. Das hätte stillschweigend "keine Funde" ergeben. Jetzt wird die Antwort richtig gelesen, und eine falsche Struktur gibt eine Meldung statt "keine Funde". Dazu ein Test.
- Negativtest live: In `01_A_ok.pdf`, `01_A4_fehler.pdf` und `03_A3_fehler.pdf` meldet die KI keinen Raum ohne Name und Fläche (richtig).
- **Noch offen für den Fundtest:** `04_A3K_fehler.pdf` (ein Raum ohne Stempel) und `05_A7K_fehler.pdf` (Ebenenwechsel ohne Höhenkote) in `testplaene/entwurf/`.

- **A6 Schnittlinien** gebaut (ohne KI): mindestens ein Schnitt, beide Enden beschriftet. **A6K Schnitt-Blickrichtung (KI)** gebaut, im Musterplan live ohne falschen Fund. Testlauf: 25 von 25 richtig.
- Für A6K fehlt noch ein Fehlerplan ohne Dreieck (optional `07_A6K_fehler.pdf`).

## Dienstag Vormittag: Fundtest der KI und was dabei herauskam

- `04_A3K_fehler.pdf` (Büro-Stempel gelöscht) und `05_A7K_fehler.pdf` sind im Ordner, dazu `05_A7K_okay.pdf` als Gegenfall.
- **A3K:** Mit PDF-Eingabe und dem kleinen Modell wurde das unbeschriftete Büro **nicht** gefunden. Mit Bild, bekannter Raumliste in der Frage und `gemini-3.8-flash` wurde es einmal gefunden, danach Zeitlimit. Die App erzeugt jetzt bei eingeschalteter KI ein Bild der Planseite im Browser (pdf.js von cdnjs) und schickt es mit.
- **A6K:** Falsche Alarme (die KI behauptet unterschiedliche Dreiecke oder ein fehlendes Dreieck, obwohl beide Dreiecke nach links zeigen).
- **A7K:** Die Testpläne zeigen keinen sichtbaren Ebenenwechsel. Nur im `okay`-Plan steht zusätzlich die Höhenkote `+0,15`. **Frage ans Team:** Wo ist der Ebenenwechsel in `05_A7K_fehler.pdf` gezeichnet?
- **Korrektur A6 (von euch):** Eine Schnittlinie darf ohne Buchstaben existieren (Strich-Punkt-Linie mit zwei Dreiecken in gleicher Richtung). A6 prüft nur noch, ob ein einzelner Buchstabe ohne Gegenstück steht. Ob eine Schnittlinie da ist, kann nur das Bild (A6K) beurteilen.
- **A1 Nordpfeil** gebaut (ohne KI, ein "N" als Text). Testlauf: 32 von 32 richtig, 2 übersprungen (KI-Pläne).
- **Offene Entscheidung:** Wie gehen wir mit den unzuverlässigen KI-Prüfungen um? (siehe Chat)

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

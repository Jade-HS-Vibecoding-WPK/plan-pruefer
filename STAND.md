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
- **Entscheidung vom Team:** A6K und A7K werden nicht gestrichen.
- **A6 neu, ohne KI:** Die Dreiecke der Schnittlinie werden jetzt direkt aus den Vektordaten des PDFs gelesen (`pruefung/pdf-grafik.ps1`). A6 prüft Schnittlinie vorhanden, Dreieck an beiden Enden, gleiche Richtung, Buchstaben falls vorhanden. Exakt, schnell, 10 neue Tests. Die KI-Variante A6K ist entfernt (falsche Alarme).
- **A7K:** Die Frage nennt jetzt den Ebenenwechsel als "durchgehende Linie mitten im Raum" und enthält die Höhenkoten aus dem Text. Im Test findet das kleine Modell die fehlende Kote `+0,15` nicht, das stärkere Modell war am Gratis-Limit. A7K bleibt experimentell.
- Testlauf: 33 von 33 richtig, 2 übersprungen.
- **Werkpläne:** Es gibt noch keinen Werkplan in `testplaene/werk/`. Vorbereitung siehe PRUEFKATALOG.md (A9, A10, A4 erweitert, A2).

## Dienstag Nachmittag

- **Neue Pläne aufgenommen:** `08_A1_fehler.pdf`, `09_A6_ok_ohne_buchstaben.pdf`, `werk/01_Werkplanung_ok.pdf`.
- **A6 verbessert:** Im Werkplan sahen Schraffur-Dreiecke (Dämmung) wie Schnitt-Dreiecke aus und Achsbuchstaben wie Schnittbuchstaben. Jetzt zählt ein Schnitt-Dreieck nur, wenn es allein steht und 8 bis 20 Punkt groß ist, Buchstaben allein zählen nie. Der Werkplan läuft ohne falschen Alarm.
- **A7K entfällt** (wie vom Team vorgesehen, weil die KI den Ebenenwechsel nicht zuverlässig fand). A7 prüft nur noch, ob ein Höhenmaß im Plan steht.
- **Testlauf:** 36 von 36 richtig, 2 übersprungen (`04_A3K_fehler` braucht die KI, `05_A7K_fehler` gehört zum entfallenen A7K).
- **Werkplanung:** Reihenfolge und Aufbau des Werkplans stehen in `PRUEFKATALOG.md`, Abschnitt "Werkplanung". Zuerst A4 Werk-Raumstempel, dann A10, A11, A9, **A2 Bemaßung** (in vier Stufen), A8, A5.

## Dienstag Abend: A4W und A10 gebaut

- **A4W Werk-Raumstempel** (nur Werkplanung, ohne KI), `pruefung/pruefpunkte/a4w-werk-raumstempel.ps1`. **Regel vom Team:** Der erweiterte Stempel (Raumnummer, RU, RH, FB, WB, DB) ist von Plan zu Plan verschieden, fehlende Angaben sind **kein Fehler**. Pflicht sind nur Raumname (prüft A3) und Fläche (prüft A4), beide laufen auch im Werkplan. A4W prüft nur Vorhandenes: Raumnummern (doppelt, Lücke in der Reihenfolge, einzelner Raum ohne Nummer, wenn andere eine haben; keine Nummern im Plan = kein Befund) und Raumhöhe RH (2,00 bis 6,00 m).
- **A10 BRH je Fenster** (nur Werkplanung), `pruefung/pruefpunkte/a10-brh.ps1`: mindestens eine BRH im Plan, jede BRH hat einen Wert (rechts daneben, bei hochkant stehendem Text darüber). Meldung mit Position. Im Musterplan 14 von 14 in Ordnung.
- Saubere Werkpläne bleiben ruhig, Entwurfs-Prüfungen unverändert. Selbsttests mit im Speicher nachgestellten Fehlern.
- Testlauf: **57 von 57 richtig**, 2 übersprungen.
- **Noch offen:** Plausibilität von Fläche und Raumumfang (kommt mit den Maßketten, A2/A5). Ob an **jedem** Fenster eine BRH steht, braucht die Fensterzahl aus der Zeichnung. Echte Fehlerpläne vom Team sind nur Gegenproben (`03_A10_fehler.pdf`).
- **Gegenprobe A10:** `03_A10_fehler.pdf` (bei einem Fenster Zahl entfernt, BRH stehen gelassen) wird mit genau einem Befund gefunden.
- **A11 Planinhalt beschriftet** (nur Werkplanung), `pruefung/pruefpunkte/a11-planinhalt.ps1`: Bezeichnung "GRUNDRISS ... M 1:50" mit Maßstab in einer Zeile vorhanden, Maßstab ist 1:50, und der Maßstab im Plankopf (unter "Maßstab") stimmt damit überein (ist er nicht lesbar, kein Befund). Testlauf: **65 von 65 richtig**, 2 übersprungen.
- **A9 Achsen** (nur Werkplanung, korrigiert 17.11.), `pruefung/pruefpunkte/a9-achsen.ps1`. **Regel vom Team:** Eine Achse erkennt man an den **Linien**: mehrere Strichpunkt- oder Strichlinien, die waagrecht und/oder senkrecht durch das Gebäude laufen, bilden das Raster. Buchstaben und Zahlen an den Achsen sind möglich, ihr Fehlen ist **kein Fehler** (sie werden nur als Information angezeigt). Die Linien werden aus den Vektordaten des PDFs gelesen (`Get-PdfLinien` in `pdf-grafik.ps1`): Ketten gleichmäßiger Striche und Punkte, mindestens 300 Punkt lang. Befund bei: keinem Raster oder nur einer einzelnen Linie. Im Musterplan: 5 senkrechte und 3 waagrechte Achsen. Grenze: Reine Strichlinien (ohne Punkte) werden nur bei sehr regelmäßigen, langen Linien erkannt. Testlauf: **75 von 75 richtig**, 2 übersprungen.
- **A2 Bemaßung** (nur Werkplanung), `pruefung/pruefpunkte/a2-bemassung.ps1`, **nach der Vorgabe vom Team** (DIN 1356-1 und DIN 406). Pro Seite (oben, unten, links, rechts), außerhalb des Achsrasters: (1) Maßkette vorhanden, (2) Gesamtmaß vorhanden (einzelne Zahl), (3) **Gesamtmaß = Summe der Öffnungsmaßkette** (Toleranz 5 mm, hochgestellte 5 zählt als halber cm, Zentimeterwerte ohne Komma zählen mit), (4) **Achse zu Achse** passt zu den Achsabständen aus den Linien (Punkt mal Maßstab), nur wenn es Achsen gibt, (5) Schreibweise: unter 1 m in cm ohne Komma, halbe cm hochgestellt. Im Musterplan stimmen alle vier Seiten (Gesamtmaß 15,99 und 13,49). BRH-Werte zählen nicht als Maßzahlen. Ohne Achsraster werden die Maßketten **nicht geprüft** (Gebäudekante nicht auffindbar). Noch nicht: Achse zu Bauteil, Innenmaße der Wände, Doppelbemaßung, Öffnungshöhen. Testlauf: **90 von 90 richtig**, 2 übersprungen.
- **Gegenprobe A2:**  5_A2_fehler.pdf (rechts Öffnungsmaß 2,43 zu 2,45 geändert) wird mit genau einem Befund gefunden: Gesamtmaß 13,49 passt nicht zur Summe 13,51.
- **A8 Eingangspfeil, neu gebaut** (Entwurf **und** Werkplanung), `pruefung/pruefpunkte/a8-eingangspfeil.ps1`. Nach euren Beispielen (`testplaene/Eingangspfeile.pdf`: Linienpfeil, Pfeil mit Dreieck, gefülltes Dreieck, Umriss-Dreieck, kleiner Pfeil; farb- und größenunabhängig): Gesucht wird eine **Pfeilspitze** (zwei gleich lange schräge Striche, die sich treffen, Öffnungswinkel 40 bis 130 Grad, Winkelhalbierende waagrecht oder senkrecht), die **in der Nähe einer Tür** steht (Türbogen im PDF, höchstens 2,5 Türbreiten Abstand) und **auf die Tür zeigt**. Alle 5 Beispielformen werden erkannt, Musterpläne (Entwurf und Werk) bleiben ruhig. Grenzen: Welche Tür die Eingangstür ist, wird nicht geprüft, ein anderer Pfeil nahe einer Tür (zum Beispiel Treppenlaufrichtung) zählt mit, deshalb übersieht A8 eher einen fehlenden Pfeil, als dass es falsch meldet. Die Vektorpfade liest die neue Funktion `Get-PdfPfade` (`pdf-grafik.ps1`).
- **A2M Maßzahl zu Maßlinie** (nur Werkplanung), `pruefung/pruefpunkte/a2m-masszahl-masslinie.ps1`: Jede Maßzahl in Metern (1,53) hat im PDF ein eigenes Maßlinien-Stück mit Querstrichen (Maßhilfslinien) an beiden Enden. Länge mal Maßstab muss die Zahl ergeben (hochgestellte 5 zählt mit). Das prüft **außen und innen** (Wand-Maßketten): im Musterplan stimmen 97 Zahlen. Toleranz 1 cm. Stücke am Kettenende und das Gesamtmaß sind im Musterplan 5 cm kürzer als die Zahl, das ist bis 6 cm erlaubt. Befund: "Zahl 2,63 passt nicht zur Maßlinie darunter (2,43 m lang)" mit Position. Nur Zahlen mit Komma, Zentimeterzahlen (zum Beispiel 49) werden nicht geprüft. Noch nicht: Maßlinie ohne Zahl, ganze fehlende Innenketten.
- **A5 Flächenplausibilität, erste Stufe** (nur Werkplanung), `pruefung/pruefpunkte/a5-flaechenplausibilitaet.ps1`: je Raum Fläche mindestens 0,5 m², Umfang RU zur Fläche plausibel (nicht kleiner als Quadrat, nicht über dem 2,5-fachen), Summe der Raumflächen gegen das Gebäuderechteck (braucht Achsraster und Gesamtmaß, sonst entfällt nur dieser Teil). **Korrektur vom Team:** NGF und RU sollen mit den **Maßen der Wand-Maßketten im Gebäude** (lichte Raummaße) verglichen werden, unabhängig vom Achsraster. Das ist die zweite Stufe und noch nicht gebaut (siehe Fragen an das Team). Testlauf: siehe unten.
- Nächster Schritt (alle Werkplanung-Punkte der Reihenfolge stehen): offen bleiben A2 Stufe 2d (Innenmaße der Wände, Achse zu Bauteil), A3K und der echte Test mit mehr Werkplänen.
- (alt) A8 Eingangspfeil, dann A5 Flächenplausibilität (Fläche und Raumumfang mit den Maßketten, wie vom Team gewünscht).
## Dienstag spät: A5 Stufe 2, schneller, Demo

- **A5 Stufe 2: NGF und RU gegen die Wand-Maßketten** (`Get-A5Wandmasse` in `a5-flaechenplausibilitaet.ps1`). Zu jedem Raumstempel werden die nächsten Maßketten im Gebäude gesucht, deren Zahl genau zur Maßlinie passt (aus A2M). Breite mal Länge gegen NGF und 2 mal (Breite plus Länge) gegen RU, oder bei nur einem Maß die andere Seite aus RU. Bis 3 Prozent in Ordnung, **3 bis 15 Prozent gelber Hinweis** (neues Schild "Hinweis" in der App, zählt im Testlauf nicht als Fehler), darüber oder ohne Maßkette nicht nachprüfbar (keine Meldung). Musterplan: Büro, Kochen, WC, HWR, Technik passen; **Wohnen/Essen 4,1 Prozent Hinweis** (Raum ist wohl nicht rechteckig); Flur nicht nachprüfbar.
- **Schneller:** Jedes PDF wird nur noch **einmal** aus den Vektordaten gelesen (`Get-PdfGrafikCached` liefert Linien, kleine Pfade und Dreiecke aus einem Durchgang). Pfeilspitzen-Suche, Achsen und Maßlinien-Zuordnung werden gemerkt. Ein Werkplan dauert im Browser jetzt etwa 40 Sekunden (vorher über 2 Minuten, gemessen während ArchiCAD lief).
- Testlauf: **122 von 122 richtig**, 2 übersprungen (Dauer jetzt etwa 12 Minuten).
- **Demo-Server** auf Port 8081: `.claude/launch.json` (Eintrag `planpruefer-demo`). Der Server auf 8080 bleibt unberührt und läuft mit altem Stand, bis ihr ihn neu startet.
- Für das Design aufgefallen: Der gelbe Hinweis zählt oben im Schild noch als "Angabe fehlt", und der Fußtext ("Geplant für Grundrisse ...") ist veraltet.

## Neues Design (Bento-Stil, nach euren Skizzen)

- `pruefung/web/index.html` neu, Farben #0F1E3A, #1E2F4F, #A7B6D0, #FFFFFF.
- **Seite 1:** Banner "PLAN PRÜFER" mit Notizzettel (abgehakt) und Lupe; Frage "Wonach soll geprüft werden?" mit zwei Kacheln Werkplanung 1:50 und Entwurf 1:100; KI-Kachel mit Schalter; PDF-Kachel (mehrere Dateien, einzeln entfernbar); Prüfung startet über die Lupe unten rechts.
- **Seite 2:** Kopfleiste mit Planprüfer-Zeichen und Pfad "Prüfung › Ergebnis"; Plan mittig (mit pdf.js gezeichnet), Befunde als nummerierte Kreise im Plan (gestrichelt = Hinweis); Dreiecke links und rechts zum Blättern, Punkte unter dem Plan, Zähler 1/2; "Geprüft auf: …"; darunter die Liste zum Abhaken (abgehakte Befunde werden im Plan blass); "n Angaben in Ordnung" zum Aufklappen; Pfeil "Zurück" unten links.
- Hinweise zählen oben getrennt ("1 Fehler offen · 1 Hinweis").
- Der Plan wird nur angezeigt, wenn pdf.js aus dem Internet geladen werden kann. Ohne Internet bleibt die Liste.

## Stand Ende Dienstag, 17.11. – hier geht es Mittwoch weiter

**Läuft:** Alle Prüfpunkte der Werk-Reihenfolge sind gebaut (A1 bis A11, dazu A2M und A5 Stufe 2), Testlauf **122 richtig, 0 falsch, 2 übersprungen** (etwa 12 Minuten). Das neue Bento-Design ist fertig und vom Team abgenommen.

**Noch zu tun von euch:** In GitHub Desktop **"Push origin"** klicken (der Demo-Commit liegt nur lokal). Server auf 8080 neu starten (`Planpruefer-starten.cmd`), damit dort das neue Design läuft.

**Ideen zum Verfeinern am Mittwoch:**
1. Design-Feinschliff nach euren Wünschen (Größen, Texte, wie stark die Markierungen auffallen).
2. Bemaßung: Maßlinie ohne Zahl melden; fehlende ganze Innenketten über eine gedachte Linie durch die Wände; Zentimeterzahlen (zum Beispiel 49) in A2M mitprüfen.
3. Frage an euch: Im Musterplan sind die Maßlinien am Kettenende 5 cm kürzer als die Zahl (1,78 gegen 1,73, Gesamtmaß 15,99 gegen 15,94). Gewollt oder Fehler? Zurzeit bis 6 cm toleriert.
4. A8 Eingangspfeil ist eine Näherung (andere Pfeile nahe einer Tür, zum Beispiel Treppenlauf, zählen mit).
5. Weitere Werkpläne mit anderem Aufbau als Test, damit die Prüfungen nicht nur zu einem Plan passen; A5-Schwellen daran prüfen.
6. Tempo (ein Werkplan etwa 40 Sekunden).
7. Donnerstag 12 Uhr Freeze, danach Poster und Demo.

## Mittwoch, 18.11.: zweiter Werkplan und genauere Maßlinien

**Eure Antwort zu den 5 cm:** Die Linien sind richtig (1,78), der Prüfer hat falsch gemessen. Ursache: ArchiCAD teilt die Maßlinie nicht genau am Querstrich, sondern 2,5 cm daneben. In der Kettenmitte hebt sich das auf, am Kettenende werden es 5 cm. Jetzt misst A2M **von Strich zu Strich**. Im Musterplan stimmen alle 97 Maßzahlen genau, die Sonderregel "Kettenende bis 6 cm kürzer" ist weg. Eine falsche Zahl am Kettenende (1,78 → 1,73) und schon 2 cm Abweichung werden gemeldet. Im Plan `05_A2_fehler` findet A2M jetzt auch den eingebauten Fehler 2,45.

**Neuer Testplan von euch** (`testplaene/werk/02_...`, ein Gebäude mit Zimmern und Bädern, Maßstriche schräg nach DIN). Zuerst gab es dort über 40 falsche Meldungen. Behoben:
- **A2M:** Schräge Maßstriche werden erkannt (197 von 198 Zahlen passen). Die Öffnungshöhen unter der Maßlinie (2,93) gelten nicht mehr als Maßzahl. Es zählen nur Striche, die mittig auf der Linie sitzen.
- **A3/A4 Raumstempel:** "NGF:" darf weiter links von der Zahl stehen (bis 80 statt 40 Punkt).
- **A4W:** Eine Zahl über dem Raumnamen (Türmaß "37") gilt nicht mehr als Raumnummer. Der Plan hat keine Raumnummern, das ist in Ordnung.
- **A2:** Die Terrassenfläche "39,59 m²" außerhalb des Gebäudes gilt nicht mehr als Gesamtmaß. Zahlen mit "m" oder "m²" daneben sind keine Maßzahlen.
- **A8:** Der Eingangspfeil ist dort ein ausgefülltes Dreieck ohne Umriss. Solche Dreiecke werden jetzt erkannt.
- **Echter Fehler im Plan** (von euch bestätigt): Zwei Terrassen oben haben keine Fläche. Deshalb heißt der Plan jetzt `02_A4_fehler.pdf`.
- Es bleiben gelbe A5-Hinweise (Fläche/Umfang gegen Wandmaße 5 bis 14 %). Die sind kein Fehler. Ob die Schwellen passen, wäre an diesem Plan noch zu klären.

**Testlauf (18.11. mittags):** **125 richtig, 0 falsch, 2 übersprungen** (etwa 15 Minuten mit dem neuen Plan). Neu dabei: `02_A4_fehler` (nur A4 meldet, alle anderen bleiben ruhig) und vier A2M-Selbsttests (2 cm Abweichung, 1 cm Rundung, Kettenende richtig gemessen, Kettenende 1,78 → 1,73).

### Mittwoch Nachmittag: zwei weitere Werkpläne

**`06_A1_fehler.pdf`** (von euch als `test_Werkplanung.pdf` abgelegt, umbenannt fürs Testschema): Diesem Plan fehlen laut euch Nordpfeil, Höhenkote, BRH, Planbezeichnung und Achsraster. Er meldet genau das (A1 dazu A7, A9, A10, A11 als bekannte Zusatzfehler). Behoben:
- **A4W:** Die **Raumliste** rechts (Nummer, Raum, FB, WB, DB) ist kein Raumstempel. Spalten ohne NGF, RU und RH werden übergangen. Die Raumnummern dieses Plans stehen über dem Namen und etwas versetzt, sie werden nicht geprüft (kein falscher Alarm).
- **A4:** "Wohnung 1" bis "4" sind keine Räume.

**`05_Werkplanung_ok.pdf`** (Museum, Modulraster 62,5 cm, Millimeter hochgestellt). Behoben:
- **A11:** Die Bezeichnung darf auch nur "Erdgeschoss … M1:50" heißen (Geschossname statt "Grundriss", "M1:50" zusammengeschrieben).
- **A6:** Ein Buchstabe, der zu einem Wort gehört ("V" "K" "Fundament"), ist kein Schnittbuchstabe.
- **A2:** Gestrichelte Linien weit außerhalb des Rasters und deutlich kürzere Strichlinien zählen für die Bemaßung nicht als Achsen. Bei einem **feinen Raster (mehr als 15 Abstände)** ist "Achse zu Achse" nur ein gelber Hinweis. Weicht ein Gesamtmaß **mit hochgestellten Millimetern** um weniger als 1 cm ab, ist das auch nur ein Hinweis (Rundung möglich). Ab 1 cm und in Plänen mit halben Zentimetern bleibt es ein Fehler.
- **A4:** "Eingang" ohne Fläche ist eine Beschriftung, kein Raum (eure Antwort).

**Testlauf (18.11. nachmittags):** **128 richtig, 0 falsch, 2 übersprungen** (alle 5 Werkpläne, etwa 15 Minuten). Der A11-Selbsttest prüft jetzt beides: Fehlt nur "GRUNDRISS", reicht "ERDGESCHOSS M 1:50". Fehlen beide Wörter, kommt ein Befund.

### Design-Wünsche vom Mittwoch (in `pruefung/web/index.html`)
- **Kacheln getauscht:** Entwurf links, Werkplanung rechts.
- **Vollbild:** Knopf "Vollbild" über dem Plan. Der Plan mit den Markierungen füllt den Bildschirm und wird in dieser Größe neu gezeichnet. Zurück mit Esc oder "Vollbild schließen". Erlaubt der Browser kein echtes Vollbild, füllt der Plan das Browserfenster (in der Vorschau getestet). Das echte Vollbild in Chrome oder Edge ist noch nicht getestet.
- **Schärfer:** Der Plan wird mit mindestens doppelter Auflösung gezeichnet (vorher 1,25-fach), höchstens 9000 Bildpunkte an der langen Seite. Große Pläne (Museum) brauchen dadurch im Browser länger zum Zeichnen.

### Schneller prüfen (Mittwoch spät)

Gemessen am Museumsplan (der größte Plan, 41.000 Linien): vorher **etwa 4 Minuten** auf dem Server, jetzt **etwa 1 Minute**. Musterplan vorher etwa 40 s. Das Prüfergebnis ist gleich geblieben.

| Schritt | vorher | jetzt | was geändert wurde |
|---|---|---|---|
| A2 Bemaßung | 71 s | 8 s | Hochzahlen nur mit Zahlen derselben Zeile vergleichen, Achsen und Zahlen werden gemerkt |
| A5 Flächen | 58 s | 2 s | nutzt die gemerkten Zahlen von A2 |
| Grafik lesen | 33–69 s | 25–29 s | Entpacken ohne Byte-Kopie, Befehle per Nachschlagen, unnötige Fälle übersprungen |
| A4 Flächen | 4 s | 0 s | Raumstempel von A3 werden wiederverwendet |

Weiter langsam: das Lesen der Grafik (bei PowerShell schwer schneller zu machen) und das Zeichnen großer Pläne im Browser.

**Testlauf danach:** **128 richtig, 0 falsch, 2 übersprungen**, der Lauf selbst dauert jetzt etwa 7 statt 15 Minuten. (Ein erster Versuch hatte 7 FALSCH, weil sich A2 Zahlen nur grob gemerkt hat. Behoben: Der Merkzettel enthält jetzt alle Texte mit Lage.)

### Ladebalken, Zoom, Schärfe (Mittwochabend, in `pruefung/web/index.html`)
- **Ring um die Lupe** füllt sich während der Prüfung, links daneben nur die geschätzte Restzeit ("ca. 0:49", Wunsch vom Team). Der Server meldet keinen Zwischenstand, die Dauer wird aus der Dateigröße geschätzt. Nach jeder Prüfung merkt sich die Seite, wie schnell der Rechner war, und schätzt dann genauer.
- **Zoom im Vollbild:** **Strg + Mausrad** (Wunsch vom Team), Mausrad allein verschiebt den vergrößerten Plan (mit Umschalt waagrecht), Ziehen zum Verschieben, Doppelklick zum Vergrößern, Knöpfe −, +, "Einpassen" unten rechts, bis 2500 %. Die Markierungen bleiben beim Zoomen etwa gleich groß.
- **Schärfe:** Im Vollbild wird der sichtbare Ausschnitt nach jedem Zoomen oder Verschieben in voller Bildschirmauflösung neu gezeichnet (getestet: bei 212 % sind alle Raumstempel lesbar). Beim Museumsplan dauert das jeweils etwa eine halbe Minute, bis dahin sieht man das normale Bild.
- **A5 Fläche gegen Wandmaße, mit Wohnflächenberechnung** (Wunsch vom Team): Die Auswertung der Pläne hat gezeigt, dass die gelben Hinweise meist von **falsch zugeordneten Maßketten** kamen (zum Beispiel Café 76 m² gegen 2,51 × 5,55 m). Wo die richtigen Ketten gefunden werden, passt die Stempelfläche genau (Technik 6,91 gegen 6,89 m², Außenterrasse 30,00 gegen 4,00 × 7,50 m). Neu:
  - Ein Hinweis kommt nur noch, wenn zwei Maßketten sicher zum Raum gehören (Fläche oder Umfang auf 1 % genau). Eine einzelne Kette mit der anderen Seite aus RU kann nur noch bestätigen.
  - Als passend gilt auch: 3 % Putzabzug, Terrasse, Balkon oder Loggia zu 25 % oder 50 %. Räume mit RH unter 2 m werden nicht verglichen.
  - Ergebnis: In allen ok-Plänen gibt es keine gelben A5-Hinweise mehr. Grenze: Hat ein Raum nur eine passende Maßkette (Büro im Musterplan), fällt eine falsche Fläche dort nicht mehr auf.
  - Testlauf danach: **131 richtig, 0 falsch, 2 übersprungen** (neue Tests: Technik Fläche +10 %, Umfang +10 %, 3 % Putzabzug, RH 1,80 m).
- **Server:** Die Seite wird nicht mehr zwischengespeichert (`Cache-Control: no-store`), sonst zeigt der Browser nach Änderungen die alte Fassung. Wirkt nach dem Neustart des Servers.

**Noch nicht gespeichert:** Die Änderungen sind nicht committet. Wenn ihr zufrieden seid, in GitHub Desktop committen und "Push origin" klicken. Damit der Server auf 8080 die neuen Prüfungen nutzt, ihn neu starten (`Planpruefer-starten.cmd`).

## Add-on Raumprogramm-Prüfer (Experiment, Mittwochabend)

**Rückweg:** Der Stand davor ist als Git-Markierung **`vor-raumprogramm`** gesichert (Commit 7a5fafb, Testlauf 131/0/2). Das Add-on lässt sich auch ohne Zurückspringen abschalten: in `pruefung/web/index.html` die zwei Zeilen unter "Add-on Raumprogramm" löschen (oder `raumprogramm.js` löschen). Die Taskleiste bleibt dann mit dem Planprüfer allein.

**Neu:**
- **Taskleiste** über dem Banner auf allen Seiten: ① Planprüfer (Werkplanung, Entwurfsplanung, Ergebnis) › ② Raumprogramm.
- **Übergang:** Sind alle Befunde abgehakt (oder gab es keine), rutscht unter der Liste die Kachel "Alles abgehakt, stark!" herein, mit Knopf zum Raumprogramm-Prüfer. Die geprüften Pläne werden mitgenommen.
- **Raumprogramm-Seite** im Bento-Layout: Kachel ① Raumprogramm (PDF), Kachel ② Grundrisse (alle Geschosse), Start über die Lupe.
- **Raum-Puzzle als Ergebnis:**
  - Jede Zeile des Raumprogramms ist eine Karte mit Soll, Ist (Summe der zugeordneten Räume) und Abweichung in m² und %.
  - Ein Füllbalken mit Soll-Strich, Farbe nach Abweichung: grün bis 10 %, gelb bis 25 %, rot darüber.
  - Die Räume liegen als Chips auf den Karten: zum Korrigieren ziehen oder antippen und dann die Karte antippen. "Nicht zugeordnet" sammelt den Rest.
  - Oben ein Ring "6/10 Zeilen belegt", die Summen und die erkannten Geschosse mit Hinweis, wenn das Programm mehrere Ebenen nennt, aber nur ein Geschoss erkannt wird. Konfetti, wenn alle Zeilen belegt sind.
- **Lesen:** Das Raumprogramm liest pdf.js im Browser (auch Word- und iPhone-PDFs; eingescannte Seiten gehen nicht). Erkannt werden Gruppen (linke Spalte), Raumnamen, Flächen ("40 qm", "m²"), "entwurfsabhängig" und die Summe. Der Text nach der Summe wird nicht beachtet. Grundrisse liest der Server (`/raeume`, nur Text, schnell): Raumstempel mit Fläche (nur Zahlen mit Komma) und das Geschoss aus Beschriftungen wie "Erdgeschoss M1:50". Zwei Grundrisse auf einem Blatt werden nach ihren Beschriftungen getrennt.
- **Zuordnung:** gleiche oder ähnliche Wörter, auch mit Tippfehlern ("Austellung"), Wortanfang ("Büro" → "Büroräume") und bekannten Gleichsetzungen (Beh.-W = WC, Anrichte = Küche).
- **Getestet:** Museumsplan gegen `testplaene/raumprogramm/Raumprogramm.pdf`: alle 10 Zeilen und die Summe 550 m² richtig gelesen, 6/10 belegt. Cafe +6,5 % (Cafe und Küche), Vortragsraum −4,8 %, Stuhllager +28,6 %, Ausstellung −34 % (nur Erdgeschoss), Hinweis "nur ein Geschoss". Ziehen, Antippen und der Weg über die Übergangs-Kachel funktionieren.
- **Dateien:** `pruefung/raumprogramm.ps1`, `pruefung/web/raumprogramm.js`, `pruefung/web/raumprogramm.css`; in `server.ps1` zwei Anschlüsse; in `index.html` Taskleiste, Seitenwechsel und die zwei Ladezeilen.
- **Fehler behoben:** Bei einem Plan ohne erkannte Geschoss-Beschriftung kam "Beim Prüfen ist ein Fehler aufgetreten" (leere Liste in PowerShell 5.1). Außerdem werden jetzt auch auseinander geschriebene Geschosse wie "GRUNDRISS OBER GESCHOSS" erkannt. Test mit `testplaene/raumprogramm/Erdgeschoss.pdf` (zeigt trotz Dateiname das **Obergeschoss**) und dem Museum-EG: beide Geschosse erkannt, 8/10 Zeilen belegt, Ausstellung EG + OG 266,90 m² (+6,8 %).
- **Wünsche vom Team (Mittwochabend):**
  - Farben nur noch aus dem Schema Navy/Weiß: bis 10 % weiß, bis 25 % hellblau (#A7B6D0), darüber blau-weiß gestreift; Abweichungs-Schild entsprechend (weiß, hellblau, Navy mit weißem Rand, gestrichelt bei "fehlt"). Keine Bewertung (kein "zu viel/zu wenig"), die Abweichung bleibt eine neutrale Zahl. Balken und Soll-Strich bleiben.
  - **Zeilen zusammenlegen:** Passen die Überschriften des Raumprogramms nicht zum Entwurf, zieht man eine Karte am Griff ≡ auf eine andere (oder Griff antippen, dann Zielkarte antippen). Soll und Räume zählen dann zusammen (Windfang/Info/Kasse in die Ausstellung: Soll 250 + 40 = 290 m²). Mit × an der eingelegten Zeile wieder trennen.
  - Leere Datei an den Server: jetzt "Das ist keine PDF-Datei." statt eines allgemeinen Fehlers.
- **Gemerkt für später:** Darstellung "Grundriss-Kacheln" (Flächen proportional zur Sollfläche). Bilder als Raumprogramm (KI oder Windows-Texterkennung).

## Stand Ende Mittwoch, 18.11. – hier geht es Donnerstag weiter (Freeze 12 Uhr)

**Läuft:**
- Planprüfer: alle Prüfpunkte, Testlauf **131 richtig, 0 falsch, 2 übersprungen** (etwa 7 Minuten).
- Fünf Werkpläne als Testfälle.
- Schneller (Museum etwa 1 statt 4 Minuten).
- Ladering mit "ca. 0:49".
- Vollbild mit Strg + Mausrad zum Zoomen und scharfem Ausschnitt.
- Taskleiste.
- Add-on Raumprogramm (Raum-Puzzle) als Experiment.

**Rückweg:** Git-Markierung `vor-raumprogramm` = Stand ohne Add-on (Präsentationsstand vom Nachmittag).

**Morgen früh zuerst:**
1. Server auf 8080 neu starten (`Planpruefer-starten.cmd`), im Browser Strg+F5.
2. Entscheiden: Add-on Raumprogramm für die Präsentation behalten oder zur Markierung zurück (oder nur die zwei Zeilen in `index.html` löschen).
3. Einmal den ganzen Ablauf durchspielen: Werkplan prüfen, alles abhaken, Raumprogramm mit Museum-EG und `R_Obergeschoss.pdf`.

**Ideen, falls Zeit ist:**
- Darstellung "Grundriss-Kacheln" für das Raumprogramm (Team wollte sie sehen).
- Raumprogramm als Bild (Screenshot): mit KI oder Windows-Texterkennung.
- Geschoss-Trennung bei zwei Grundrissen auf einem Blatt an einem echten Plan testen.
- Raumnummern über dem Raumnamen (Plan `06_A1_fehler`) prüfen.

## Ältere Aufgabenliste (vom Montag, größtenteils erledigt)

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

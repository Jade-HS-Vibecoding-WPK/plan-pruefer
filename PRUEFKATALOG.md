# Prüfkatalog (Entwurf aus dem Interview)

Stand: Entwurf, noch von euch gegenzulesen. Die Plankopf-Prüfung entfällt, sie war ein Testlauf.

## Rahmen

| Punkt | Entscheidung |
|-------|--------------|
| Plantypen | zunächst **nur Grundrisse** |
| Eingabe | **PDF** aus ArchiCAD. IFC kommt später dazu (vor allem für Gruppe B und C) |
| Priorität | **Gruppe A** (zeichnerische Pflichtinhalte) zuerst, danach B (Maße, Vorschriften) und C (Rechenwerte) |
| Ergebnis | Befundliste mit "Korrigiert"-Haken **und** Markierung der Stelle im Plan |
| KI | **Google Gemini**, nur kostenloser Zugang. Als austauschbarer Baustein gebaut, damit ein späterer Wechsel einfach bleibt |
| Datenschutz | An die KI gehen nur eigene, unkritische Studienpläne. Der API-Schlüssel kommt nie ins Git |

## Prüfpunkte Gruppe A

| Nr. | Prüfpunkt | Was geprüft wird | Technik | Schwierigkeit |
|-----|-----------|------------------|---------|---------------|
| A1 | Nordpfeil | Ist ein Nordpfeil im Plan **vorhanden**? (Die Richtung wird nicht geprüft.) | KI (Bild) | mittel |
| A2 | Bemaßung | Gesamtmaße, Außenmaßketten (alle Seiten), Raummaße innen, Öffnungsmaße (Fenster und Türen) | PDF-Text mit Positionen, Geometrie, ggf. KI | **schwer** |
| A3 | Raumbezeichnungen | Jeder Raum hat einen Namen | PDF-Text, für Räume ohne Beschriftung Geometrie oder KI | mittel |
| A4 | Raumflächen | Zu jedem Raum steht eine Fläche in m² | PDF-Text | leicht |
| A5 | Flächenangabe plausibel | Die Fläche passt zu den Raummaßen | PDF-Text und Rechnung | mittel bis schwer |
| A6 | Schnittlinien | Mindestens ein Schnitt vorhanden, Beschriftung an beiden Enden, Blickrichtung gekennzeichnet | Geometrie, PDF-Text, ggf. KI | mittel bis schwer |
| A7 | Höhenangaben | Fußbodenhöhe je Geschoss, Höhen an Raumebenen (Stufen, Terrasse, Bad) | PDF-Text | leicht bis mittel |

Nicht gewählt (kann später kommen): Legende und Schraffuren, Kennzeichnung Bestand/Neu/Abbruch, Nutzungsnamen nach fester Liste.

## Abgleich mit den Hochschul-Checklisten (Ordner `unterlagen/`)

Gelesen: *Checkliste Entwurfsplanung* (Grundrisse M 1:100) und *Checkliste Werkplanung* (Grundrisse M 1:50). Beide enthalten außerdem Lageplan, Ansichten und Schnitte, die für den Start entfallen (nur Grundrisse).

**Was die Checklisten für den Grundriss fordern und wie es zu unserem Katalog passt:**

| Forderung der Hochschule | Entwurf | Werk | Im Katalog |
|--------------------------|:------:|:----:|------------|
| Nordpfeil | G.1.1 | G.1.6 | A1 |
| **Eingangspfeil** | G.1.2 | G.1.7 | **neu: A8** (Zeichnung, KI) |
| Schnittführung mit Bezeichnung und Blickrichtung | G.1.4 | G.1.5 | A6 |
| Gesamtmaß, Außenmaß | G.2.1 | G.2.3 | A2 |
| Außenmaße, Öffnungsmaße, Innenmaße | – | G.2.3 | A2 |
| Achsen vermaßt, mit Bezeichnung | – | G.1.4, G.2.1 | **neu: A9** |
| Höhenkoten | G.2.2 | G.2.4 | A7 |
| **Brüstungshöhe (BRH) bei jedem Fenster, auch bei 0,00** | – | G.2.5 | **neu: A10** (Text) |
| Raumstempel mit Raumbezeichnung und Fläche | G.3.1 | G.3.1 | A3, A4 |
| Raumstempel zusätzlich mit **Umfang, Raumhöhe, Bodenbelag** | – | G.3.1 | A4 erweitert |
| **Beschriftung des Planinhalts mit Angabe des Maßstabs** (zum Beispiel "Grundriss EG M 1:100") | G.3.2 | G.3.6 | **neu: A11** (Text) |
| Plankopf mit allen wesentlichen Projektangaben | G.3.4 | G.3.7 | **Widerspruch**, siehe unten |

**Nicht für Stufe 1** (reine Darstellungsfragen, schwer zu prüfen): Möblierung, Schraffuren, Linienarten (gepunktet, gestrichelt), vereinfachte Fenster und Türen, Bodenbeläge zeichnen, Fundamente, Estrichtrennfugen, Durchbrüche.

**Widerspruch Plankopf:** Beide Checklisten fordern einen Plankopf mit allen wesentlichen Projektangaben. Wir haben die ausführliche Plankopf-Prüfung entfernt, weil Planköpfe zu individuell sind. Eine sehr einfache Prüfung "Plankopf vorhanden" bleibt als möglicher Punkt (Vorschlag: A12).

**Entwurf oder Werkplanung?** Die beiden Checklisten unterscheiden sich im Umfang (Werkplanung verlangt mehr, zum Beispiel Achsen, BRH, Raumstempel mit Umfang, Höhe und Belag). Die App muss wissen, welche Liste gilt. Der Maßstab im Plan gibt einen Hinweis: 1:100 für Entwurf, 1:50 für Werkplanung.

**Weitere Unterlagen:**
- *Perfect Scale* (Schulz & Schulz) ist ein Buch über Darstellung und Detailtiefe je Maßstab (1:2000 bis 1:1). Es passt zu einer späteren Gruppe "Darstellung" (Linienstärken, Detailtiefe), nicht zu Stufe 1.
- *Raumpilot 2012* (1604 Seiten, Wüstenrot Stiftung) ist ein Planungshandbuch mit Raumgrößen. Es eignet sich später für die Plausibilität von Raumflächen (Gruppe B/C). Der Text im PDF ist verschlüsselt kodiert und war so nicht ohne Weiteres lesbar.

## Vorgeschlagene Reihenfolge (einfachstes zuerst)

1. **A4** Raumflächen vorhanden (reiner Text)
2. **A7** Höhenangaben (reiner Text)
3. **A3** Raumbezeichnungen
4. **A6** Schnittlinien
5. **A1** Nordpfeil (erste Nutzung der KI)
6. **A5** Flächenangabe plausibel
7. **A2** Bemaßung (am schwierigsten, deshalb zuletzt)

Jeder Punkt wird einzeln gebaut, getestet und committet. Dazu brauchen wir pro Punkt einen sauberen Plan und einen Plan mit dem Fehler.

## Bekannte Risiken

- **Räume ohne Beschriftung:** Ein Raum ohne Raumstempel erscheint im PDF-Text gar nicht. Ihn zu finden, braucht Geometrie oder KI. Damit steht A3 auf wackligerem Boden, als es zunächst aussieht.
- **Markierung im Plan:** Dafür braucht die App die Position jedes Befunds. Bei Textstellen haben wir sie schon. Für Befunde "etwas fehlt" (zum Beispiel kein Nordpfeil) gibt es keine Stelle, hier markieren wir den ganzen Plan oder zeigen nur den Hinweis.
- **KI-Limits:** Der kostenlose Gemini-Zugang hat Mengenlimits, die sich ändern. Die KI wird deshalb nur für Zeichnungen verwendet, die sich nicht anders prüfen lassen.

## Offen

- Hochschul-Dokumente (Entwurfszeichnungen, Werkplanungen) in den Ordner `unterlagen/` legen. Daraus wird gefiltert, welche Kriterien für Grundrisse in Stufe 1 gelten.
- Testpläne je Prüfpunkt besorgen (sauber und mit Fehler) und in `testplaene/entwurf/` bzw. `testplaene/werk/` ablegen, Benennung siehe `testplaene/LIESMICH.md`. Die alten Plankopf-Testpläne in `archiv/testplaene/` zählen dafür nicht.

## Erkenntnisse zur KI (Stand 17.11.)

- **PDF-Eingabe ist für Zeichnungen ungeeignet.** Gemini liest aus einem PDF vor allem den Text. Ein Raum ohne Text ist für die KI unsichtbar. Deshalb erzeugt die Seite bei eingeschalteter KI ein Bild der Planseite (pdf.js im Browser) und schickt es mit.
- **Die Frage muss gezielt sein.** "Liste alle Räume" zählt nur die beschrifteten. Besser: die bekannten Räume nennen und nach **weiteren** fragen.
- **Das stärkere Modell hilft, kostet aber Zeit und Zuverlässigkeit.** `gemini-3.8-flash` fand den unbeschrifteten Raum, antwortet aber langsam (bis 90 s pro Plan, teils Zeitlimit oder "hohe Nachfrage"). Das kleine `gemini-3.5-flash-lite` ist schnell, übersieht aber den Raum.
- **Kleine Zeichenelemente sind schwach.** Die KI meldete bei zwei gleich gerichteten Dreiecken falsche Alarme (die Dreiecke sind nur etwa 30 Pixel groß) und nannte auch auf vergrößerten Ausschnitten die falsche Richtung ("unten" statt "links").
- **Geometrie schlägt KI, wo sie geht.** Dreiecke, Texte und Koordinaten stehen im PDF als Daten. A6 liest die Dreiecke deshalb direkt aus dem PDF (`pdf-grafik.ps1`) und ist exakt und schnell (etwa 2 Sekunden). Die KI bleibt für das, was sich nicht aus Daten ergibt (unbeschriftete Räume, Ebenenwechsel).
- **Gratis-Limits setzen Grenzen.** Das stärkere Modell antwortet oft nach über einer Minute, läuft ins Zeitlimit oder meldet "Limit erreicht".
- **KI-Funde bleiben Hinweise.** Sie sind nie die einzige Grundlage einer Aussage.

## Stand der Umsetzung

| Nr. | Prüfpunkt | Stand |
|-----|-----------|-------|
| A4 | Raumflächen | **gebaut** (Entwurf und Werk, Grundversion: Fläche je Raumstempel). Der Werk-Zusatz ist ein eigener Prüfpunkt (A4W, nächste Zeile) |
| A4W | Werk-Raumstempel | **gebaut, neu ausgerichtet 17.11. (Entscheidung Team)** (nur Werkplanung, ohne KI, `a4w-werk-raumstempel.ps1`): Ob der erweiterte Stempel (Raumnummer, RU, RH, FB, WB, DB) vollständig ist, ist von Plan zu Plan verschieden, **fehlende erweiterte Angaben sind kein Fehler**. Pflicht sind nur Raumname (A3) und Fläche (A4), beide laufen auch in der Werkplanung. A4W prüft nur Vorhandenes: **Raumnummern** (doppelt? lückenlos? Hat ein Raum keine Nummer, obwohl andere eine haben, wird es gemeldet; hat kein Raum eine, kein Befund) und **Raumhöhe RH** (muss 2,00 bis 6,00 m sein). **Später mit den Maßketten (A2/A5):** Plausibilität von Fläche und Raumumfang |
| A10 | BRH je Fenster | **gebaut** (nur Werkplanung, ohne KI): mindestens eine BRH-Angabe im Plan, jede BRH hat einen Wert (Zahl rechts daneben, bei hochkant stehendem Text darüber), Befund mit Position. Noch nicht: Abgleich mit der Fensterzahl |
| A3 | Raumbezeichnungen | **gebaut** (Entwurf und Werk). Grenze: Ein Raum ohne Name **und** ohne Fläche steht nicht im PDF-Text und wird nicht gefunden (dafür bräuchte es Geometrie oder KI) |
| A3K | Raum ohne Name und Fläche (KI) | **gebaut, Fundtest 17.11. gemischt.** Mit dem kleinen Modell und PDF-Eingabe wird der unbeschriftete Raum **nicht** gefunden (die KI zählt nur beschriftete Räume). Mit dem Bild, der Liste der schon bekannten Räume in der Frage und dem stärkeren Modell `gemini-3.8-flash` wurde das Büro in `04_A3K_fehler.pdf` einmal **gefunden**, spätere Läufe liefen aber ins Zeitlimit. Läuft nur mit eingeschalteter KI, Ergebnis ist ein Hinweis |
| A7 | Höhenangaben (Fußbodenhöhe) | **gebaut** (Entwurf und Werk): mindestens eine Höhenkote wie ±0,00 im Plan, ohne KI |
| A7K | Höhenangabe an Raumebenen (KI) | **entfällt (Entscheidung Team 17.11.).** Die KI konnte den Ebenenwechsel nicht zuverlässig erkennen (das kleine Modell findet die fehlende Kote nicht, das stärkere Modell erreicht das Gratis-Limit). A7 prüft nur noch, ob **ein Höhenmaß im Plan enthalten ist**. Die Pläne  5_A7K_fehler.pdf und  5_A7K_okay.pdf bleiben im Ordner, der Fehlerplan wird übersprungen |
| A1 | Nordpfeil | **gebaut** (Entwurf und Werk, ohne KI): ein einzelnes großes "N" als Text im Plan. Grenze: Ein Nordpfeil ohne Buchstaben wird nicht erkannt (unberechtigter Befund), ein "N" ohne Zeichnung geht durch |
| A6 | Schnittlinien (Dreiecke und Buchstaben) | **gebaut, ohne KI** (Entwurf und Werk): Die Dreiecke an den Enden werden als Vektorformen aus dem PDF gelesen. Geprüft wird: Schnittlinie vorhanden, an beiden Enden ein Dreieck, beide in dieselbe Richtung, Buchstaben (falls vorhanden) an beiden Enden gleich. **Schnittlinien ohne Buchstaben sind in Ordnung** (Korrektur vom Team 17.11.). Grenze: nur senkrechte oder waagerechte Linien mit rechtwinklig angeordneten Dreiecken, Schnitt-Dreiecke ab 8 Punkt Kante |
| A2, A5, A8 bis A11 | | noch nicht gebaut |

## Entschieden

- Der **Nordpfeil** muss nur vorhanden sein, die Richtung wird nicht geprüft.
- Die **Plankopf-Prüfung** ist aus der App entfernt und liegt als Vorlage in `archiv/plankopf/`.
- Die Nutzerin **wählt vor dem Hochladen die Planungsphase** und wird bei jedem Besuch neu danach gefragt (die Auswahl wird nicht gespeichert): Entwurfsplanung (Checkliste Entwurf, 1:100) oder Werkplanung (Checkliste Werk, 1:50). Jeder Prüfpunkt legt in `pruefung/pruefungen.ps1` fest, für welche Phase er gilt.

## Werkplanung (Grundrisse 1:50): Reihenfolge und Plan

**Stand:** Der saubere Werkplan `testplaene/werk/01_Werkplanung_ok.pdf` (Format A1, 1:50) läuft durch alle bisherigen Prüfpunkte (A1, A3, A4, A6, A7) **ohne falschen Alarm**. Dafür mussten zwei Dinge angepasst werden: A6 ignoriert Dreiecke in Schraffuren (Dämmung besteht aus vielen Dreiecken) und zählt Achsbuchstaben nicht als Schnitt.

**Wie der Werkplan im PDF aufgebaut ist** (aus dem Plan ausgelesen, danach richten sich die Prüfungen):
- **Raumstempel:** Raumname, Raumnummer (01 bis 06), `NGF:` Fläche, `RU:` Raumumfang, `RH:` Raumhöhe, `FB:` Fußbodenbelag, `WB:` Wandbelag, `DB:` Deckenbelag.
- **Achsen:** Kreise mit Buchstaben A bis E (oben und unten) und Ziffern 1 bis 3 (links und rechts), gestrichelte Achslinien.
- **Maßketten** an allen vier Seiten, jeweils beschriftet: `Achse zu Bauteil`, `Achse zu Achse`, `Gesamtmaß`, `Öffnungsmaße`.
- **BRH-Angaben:** 14 Stück, "BRH 95" oder "BRH 0,00", an jedem Fenster.
- **Höhenkoten:** `±0,00 OK Gelände`, `±0,00 OKFF EG`, `-0,20 OKRF EG`.
- **Planinhalt:** "GRUNDRISS ERDGESCHOSS M 1:50", Legende, Nordpfeil, **roter Eingangspfeil** (großes Dreieck, etwa 28 Punkt), Schnittlinie A.

### Sinnvolle Reihenfolge

| Schritt | Punkt | Was wird geprüft | Art | Warum an dieser Stelle |
|---------|-------|------------------|-----|------------------------|
| 1 | **A4 Werk-Raumstempel (A4W)** ✔ gebaut 17.11. | Jeder Raumstempel hat Raumnummer, Fläche, Umfang (RU), Raumhöhe (RH) und die drei Beläge (FB, WB, DB) mit Wert | Text | Aufbau ist bekannt, schnell und sicher, trifft Checkliste G.3.1 |
| 2 | **A10 BRH je Fenster** ✔ gebaut 17.11. | Jede BRH-Angabe hat einen Wert; später Abgleich mit der Fensterzahl | Text, später Geometrie | Text steht im PDF (14 Stück), gleiche Technik wie Schritt 1 |
| 3 | **A11 Planinhalt beschriftet** | "Grundriss ... M 1:50" steht im Plan, Maßstab stimmt zum Plankopf | Text | sehr einfach, trifft G.3.6 |
| 4 | **A9 Achsen** | Achsen A bis E und 1 bis 3 an beiden Enden bezeichnet, keine Lücke in der Reihenfolge, Achsmaßketten vorhanden | Text, Geometrie | baut auf dem Wissen über Buchstaben und Kreise auf |
| 5 | **A2 Bemaßung** (nicht vergessen, siehe unten) | Maßketten vollständig und richtig | Text, Geometrie | größter Brocken, braucht die Vorarbeit aus Schritt 4 |
| 6 | **A8 Eingangspfeil** | Der Eingangspfeil ist vorhanden | Geometrie (großes Dreieck, Farbe rot) | Das Dreieck ist im PDF schon gefunden, aber nur im Werkplan sichtbar |
| 7 | **A5 Flächenplausibilität** | Fläche passt zu Raummaßen (der Werkplan enthält jetzt den Umfang RU, damit lässt sich rechnen) | Text und Rechnung | erst möglich, wenn A4 Werk steht |
| 8 | A3K (KI), Plankopf-Frage A12 | unbeschrifteter Raum, "Plankopf vorhanden" | KI, Text | experimentell bzw. Entscheidung offen |

### Bemaßung (A2) im Detail, wird ausdrücklich nicht vergessen

Die Bemaßung ist wichtig und wird in vier kleinere Stufen geteilt, damit jede für sich testbar bleibt:

| Stufe | Prüfung | Grundlage im Werkplan | Schwierigkeit |
|-------|---------|-----------------------|---------------|
| 2a | **Maßketten vorhanden:** An allen vier Seiten gibt es Gesamtmaß und Öffnungsmaße, im Werkplan zusätzlich Achse zu Achse und Achse zu Bauteil | Beschriftungen der Maßketten stehen als Text, die Seite ergibt sich aus der Position | leicht |
| 2b | **Summenprobe (Richtigkeit):** Das Gesamtmaß ist gleich der Summe der Teilmaße einer Kette (zum Beispiel 15,99 m) | Maßzahlen stehen als Text, nach Zeile und Position zu einer Kette gruppierbar | mittel |
| 2c | **Öffnungsmaße vollständig:** Jedes Fenster und jede Tür hat Breite und Brüstungs- oder Höhenmaß ("2,51 über 1,30") | Zahlenpaare übereinander im Text | mittel |
| 2d | **Mauermaße und Innenmaße:** Außenwandstärke in der Maßkette (zum Beispiel 49 cm), Raummaße innen | Text, Zuordnung zu Wänden schwer | schwer, am Schluss |

Für den **Entwurf** gilt eine kleinere Fassung: Gesamtmaß und Außenmaß (Checkliste G.2.1).

### Was ihr dafür beisteuern könnt
Für jeden Schritt hilft **ein Fehlerplan** aus eurem sauberen Werkplan, jeweils mit **einem** Fehler (so kann der Testlauf ihn zuordnen):

| Datei in `testplaene/werk/` | Fehler |
|-----------------------------|--------|
| `02_A4_fehler.pdf` | bei einem Raum fehlt Umfang, Raumhöhe oder ein Belag |
| `03_A10_fehler.pdf` | bei einem Fenster fehlt BRH, oder die BRH hat keinen Wert |
| `04_A9_fehler.pdf` | an einem Ende fehlt eine Achsbezeichnung |
| `05_A2_fehler.pdf` | an einer Seite fehlt das Gesamtmaß, oder eine Maßzahl ist so geändert, dass die Summe nicht mehr stimmt (am besten **zwei getrennte Dateien**: `05_A2_fehler_gesamtmass-fehlt.pdf`, `06_A2_fehler_summe.pdf`) |
| `07_A8_fehler.pdf` | der Eingangspfeil fehlt |
| `08_A6_fehler.pdf` | bei der Schnittlinie fehlt ein Dreieck (Werkplan) |

Bis der Fehlerplan da ist, baue ich jeden Punkt zuerst mit **nachgestellten Fehlern im Speicher**, wie bei A4 und A6. Die echten Pläne kommen dann als Gegenprobe dazu.
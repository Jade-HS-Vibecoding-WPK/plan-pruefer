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
- Testpläne je Prüfpunkt besorgen (sauber und mit Fehler). Der frühere Plan ohne Nordpfeil (`02_einfamilienhaus_falsch.pdf`) liegt nicht mehr im Ordner `testplaene/`, falls er noch gebraucht wird, bitte wieder ablegen.

## Entschieden

- Der **Nordpfeil** muss nur vorhanden sein, die Richtung wird nicht geprüft.
- Die **Plankopf-Prüfung** ist aus der App entfernt und liegt als Vorlage in `archiv/plankopf/`.

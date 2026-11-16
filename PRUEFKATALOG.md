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

## Stand der Umsetzung

| Nr. | Prüfpunkt | Stand |
|-----|-----------|-------|
| A4 | Raumflächen | **gebaut** (Entwurf und Werk, Grundversion: Fläche je Raumstempel). Werk-Zusatz (Umfang, Raumhöhe, Bodenbelag) fehlt noch |
| A3 | Raumbezeichnungen | **gebaut** (Entwurf und Werk). Grenze: Ein Raum ohne Name **und** ohne Fläche steht nicht im PDF-Text und wird nicht gefunden (dafür bräuchte es Geometrie oder KI) |
| A3K | Raum ohne Name und Fläche (KI) | **gebaut, aber noch nicht mit der echten KI getestet** (es fehlt der Schlüssel und ein Testplan). Läuft nur, wenn die Nutzerin die KI einschaltet, Ergebnis ist ein Hinweis zur Prüfung durch Menschen |
| A1, A2, A5 bis A11 | | noch nicht gebaut |

## Entschieden

- Der **Nordpfeil** muss nur vorhanden sein, die Richtung wird nicht geprüft.
- Die **Plankopf-Prüfung** ist aus der App entfernt und liegt als Vorlage in `archiv/plankopf/`.
- Die Nutzerin **wählt vor dem Hochladen die Planungsphase** und wird bei jedem Besuch neu danach gefragt (die Auswahl wird nicht gespeichert): Entwurfsplanung (Checkliste Entwurf, 1:100) oder Werkplanung (Checkliste Werk, 1:50). Jeder Prüfpunkt legt in `pruefung/pruefungen.ps1` fest, für welche Phase er gilt.

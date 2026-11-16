# plan-pruefer

Ein Tool, das Baupläne auf Vollständigkeit und Richtigkeit prüft

## Idee

Der Planprüfer ist eine Web-App für Architekturstudierende. Man lädt einen Grundriss als PDF hoch (Export aus ArchiCAD) und bekommt eine Liste mit Befunden zurück.

Die Prüfpunkte wachsen Schritt für Schritt. Die Einzelheiten stehen in [PRUEFKATALOG.md](PRUEFKATALOG.md), der Zeitplan in [PLAN.md](PLAN.md).

### Was der Planprüfer können soll

**Eingabe**
- Zunächst nur **Grundrisse** als PDF aus ArchiCAD mit auslesbarem Text.
- Später: Schnitte, Ansichten und ganze Plansätze. IFC-Dateien kommen als Erweiterung, vor allem für Maße und Rechenwerte.

**Gruppe A: zeichnerische Pflichtinhalte (zuerst)**
- Nordpfeil vorhanden
- Bemaßung: Gesamtmaße, Außenmaßketten, Raummaße innen, Öffnungsmaße
- Raumbezeichnungen: Jeder Raum hat einen Namen
- Raumflächen: Jeder Raum hat eine Fläche, und die Angabe ist plausibel
- Schnittlinien: mindestens ein Schnitt, Beschriftung an beiden Enden, Blickrichtung
- Höhenangaben: Fußbodenhöhe je Geschoss und an Raumebenen

**Danach**
- Gruppe B: Maße und Vorschriften (zum Beispiel Türbreiten, Flure, Treppen, Fluchtwege)
- Gruppe C: Rechenwerte (zum Beispiel Summe der Raumflächen, NGF/BGF)
- Gruppe D: Abgleich mehrerer Pläne und Vollständigkeit des Plansatzes
- Abgabekriterien der Hochschule (Entwurfszeichnungen, Werkplanungen) und Bauordnung

**Ergebnis**
- Eine Liste mit Befunden, die man abhaken kann, sobald der Fehler korrigiert ist.
- Markierungen direkt im Plan an der Stelle des Befunds.

**Technik (grob)**
- Feste Regeln für alles, was sich aus dem Text des PDFs ergibt.
- KI für Zeichnungen, die sich nicht anders prüfen lassen (zum Beispiel der Nordpfeil). Gewählt ist Google Gemini im kostenlosen Zugang, als austauschbarer Baustein. Dabei dürfen nur eigene, unkritische Studienpläne gesendet werden.

## App starten

Doppelklick auf `Planpruefer-starten.cmd`. Das Fenster offen lassen, der Browser öffnet `http://localhost:8080`.

## Ordner

| Ordner / Datei | Inhalt |
|----------------|--------|
| `pruefung/` | Server, Weboberfläche und die Prüfpunkte |
| `testplaene/` | Beispielpläne für die Grundriss-Prüfung, getrennt nach `entwurf/` und `werk/` (nur lokal, nicht im Git) |
| `unterlagen/` | Hochschul-Dokumente (nur lokal, nicht im Git) |
| `archiv/plankopf/` | Erster Testlauf: Plankopf-Prüfung, nicht mehr Teil der App |
| `archiv/testplaene/` | Die Testpläne zur Plankopf-Prüfung (nur lokal, nicht im Git) |

### Offene Punkte

- Welche Bauordnung (Bundesland) gilt, ist noch nicht festgelegt.
- Die Kriterien der Hochschule müssen aus den Dokumenten für Entwurfszeichnungen und Werkplanungen herausgefiltert werden.

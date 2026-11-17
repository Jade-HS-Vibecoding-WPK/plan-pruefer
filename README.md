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

## KI-Prüfung einrichten (optional)

Manche Prüfungen, zum Beispiel "Raum ohne Name und Fläche", macht eine KI (Google Gemini). Sie ist standardmäßig **aus** und muss bei jedem Upload ausdrücklich eingeschaltet werden.

1. Auf [Google AI Studio](https://aistudio.google.com/apikey) mit einem Google-Konto einen kostenlosen API-Schlüssel erstellen.
2. Die Datei `schluessel.beispiel.txt` kopieren, die Kopie `schluessel.txt` nennen und den Schlüssel einfügen. Die App liest auch eine Datei `schluessel.env` oder `.env`. Erlaubt ist nur der Schlüssel in einer Zeile oder die Schreibweise `GEMINI_API_KEY=...`. Der Platzhalter `HIER-DEN-SCHLUESSEL-EINFUEGEN` zählt nicht. Alle diese Dateien stehen in der `.gitignore`.
3. App neu starten. Auf der Seite ist die KI-Option dann wählbar.

Wichtig:
- `schluessel.txt` wird nie auf GitHub hochgeladen. Den Schlüssel nicht weitergeben.
- Bei eingeschalteter KI wird der Plan an Google gesendet. Im kostenlosen Zugang darf Google die Eingaben zur Verbesserung seiner Produkte nutzen. Deshalb nur eigene, unkritische Pläne verwenden.
- KI-Funde sind **Hinweise** und müssen von einem Menschen geprüft werden.
- Der kostenlose Zugang hat Mengenlimits. Ist das Limit erreicht, zeigt die App eine Meldung, und die normalen Prüfungen laufen weiter.

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

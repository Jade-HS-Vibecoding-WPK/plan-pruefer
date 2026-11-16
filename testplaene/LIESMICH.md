# Testpläne für die Grundriss-Prüfung

Hier liegen die Beispielpläne (PDF aus ArchiCAD), an denen die Prüfpunkte der Gruppe A getestet werden.
Die Pläne selbst werden **nicht** ins Git hochgeladen (siehe `.gitignore`), sie bleiben nur auf den eigenen Rechnern.

Die alten Testpläne der Plankopf-Prüfung liegen im Archiv (`archiv/testplaene/`) und werden hier **nicht** verwendet.

## Aufbau

| Ordner | Inhalt |
|--------|--------|
| `entwurf/` | Grundrisse M 1:100 für die Prüfung als **Entwurfsplanung** |
| `werk/` | Grundrisse M 1:50 für die Prüfung als **Werkplanung** |

## Benennung

`<prüfpunkt>_<ok|fehler>_<kurzbeschreibung>.pdf`, zum Beispiel:

- `A4_ok_einfamilienhaus.pdf` – alle Raumflächen vorhanden, es darf kein Befund kommen
- `A4_fehler_flaeche-fehlt-flur.pdf` – beim Raum "Flur" fehlt die Fläche, genau dieser Befund muss kommen

Ein Plan ohne Zusatz (`ok_gesamt`) darf für **alle** Prüfpunkte keinen Befund auslösen.

## Prüfpunkte

Die Nummern stammen aus [PRUEFKATALOG.md](../PRUEFKATALOG.md).

| Nr. | Prüfpunkt | Phase |
|-----|-----------|-------|
| A1 | Nordpfeil vorhanden | Entwurf, Werk |
| A2 | Bemaßung (Gesamtmaße, Außenmaßketten, Raummaße, Öffnungsmaße) | Entwurf (Gesamt-, Außenmaß), Werk (alles) |
| A3 | Raumbezeichnungen | Entwurf, Werk |
| A4 | Raumflächen (Werk zusätzlich Umfang, Raumhöhe, Bodenbelag) | Entwurf, Werk |
| A5 | Flächenangabe plausibel | Entwurf, Werk |
| A6 | Schnittlinien mit Bezeichnung und Blickrichtung | Entwurf, Werk |
| A7 | Höhenangaben | Entwurf, Werk |
| A8 | Eingangspfeil | Entwurf, Werk |
| A9 | Achsen vermaßt und bezeichnet | Werk |
| A10 | Brüstungshöhe (BRH) bei jedem Fenster | Werk |
| A11 | Maßstab im Planinhalt beschriftet | Entwurf, Werk |

## Fehlerliste

Zu jedem Plan mit Fehler notieren wir, welcher Fehler eingebaut ist. Die Spalte "Gefunden?" füllen wir nach dem Test aus.

| Datei | Phase | Eingebauter Fehler | Gefunden? |
|-------|-------|--------------------|-----------|
| | | | |

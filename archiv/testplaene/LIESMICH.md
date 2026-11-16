# Testpläne

Hier liegen die Beispielpläne (PDF), an denen der Planprüfer getestet wird.
Die Pläne selbst werden **nicht** ins Git hochgeladen (siehe `.gitignore`), sie bleiben nur auf den eigenen Rechnern.

## Benennung

`<nr>_<kurzname>_<ok|fehler>.pdf`, zum Beispiel:

- `01_einfamilienhaus_ok.pdf` – sauberer Plan, es sollte keine Befunde geben
- `02_einfamilienhaus_fehler.pdf` – Plan mit absichtlich eingebauten Fehlern

## Fehlerliste

Zu jedem Plan mit Fehlern notieren wir unten, welche Fehler eingebaut sind. So sehen wir, ob das Tool sie findet.

| Datei | Eingebauter Fehler | Gefunden? |
|-------|--------------------|-----------|
| 02_einfamilienhaus_falsch.pdf | Nordpfeil fehlt (Zeichnung, erst ab Stufe 2 prüfbar) | |
| 03_einfamilienhaus_falsch.pdf | Baumaßnahme fehlt | |
| 04_einfamilienhaus_falsch.pdf | Bauort fehlt | |
| 05_einfamilienhaus_falsch.pdf | Bauherr fehlt | |
| 06_einfamilienhaus_falsch.pdf | Planbezeichnung fehlt | |
| 07_einfamilienhaus_falsch.pdf | Planer fehlt | |
| 08_einfamilienhaus_falsch.pdf | Datum fehlt | |
| 09_einfamilienhaus_falsch.pdf | Maßstab fehlt | |
| 10_einfamilienhaus_falsch.pdf | Plannummer fehlt | |

## Plankopf-Varianten ohne Fehler

- `01_einfamilienhaus_ok.pdf` und `02_einfamilienhaus_ok.pdf` sind identisch (Layout 1).
- `02_einfamileienhaus_ok_plankopf variante 2.pdf` (Layout 2)
- `02_einfamileienhaus_ok_plankopf variante 3.pdf` (Layout 3)
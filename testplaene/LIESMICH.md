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
| 02_einfamilienhaus_fehler.pdf | Nordpfeil fehlt |
| 03_einfamilienhaus_fehler.pdf | Baumaßnahme fehlt |
| 04_einfamilienhaus_fehler.pdf | Bauort fehlt |
| 05_einfamilienhaus_fehler.pdf | Bauherr fehlt |
| 06_einfamilienhaus_fehler.pdf | Planbezeichnung fehlt |
| 07_einfamilienhaus_fehler.pdf | Planer fehlt |
| 08_einfamilienhaus_fehler.pdf | Datum fehlt |
| 09_einfamilienhaus_fehler.pdf | Maßstab fehlt |
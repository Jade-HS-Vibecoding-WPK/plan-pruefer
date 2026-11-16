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

`<nr>_<prüfpunkt>_<ok|fehler>.pdf` (der Testlauf liest die Erwartung aus dem Namen), zum Beispiel:

- `01_A_ok.pdf` – sauberer Plan, **kein** Prüfpunkt darf einen Befund melden
- `01_A4_fehler.pdf` – Plan mit Fehler bei A4 (Raumflächen): A4 muss einen Befund melden, alle anderen Prüfpunkte müssen ruhig bleiben

Zusätze nach `ok` oder `fehler` sind erlaubt (zum Beispiel `02_A4_fehler_flur.pdf`).

## Testlauf

Aus dem Projektordner:

    powershell -File pruefung\testlauf.ps1

Der Testlauf prüft alle Pläne in `entwurf/` und `werk/`, meldet pro Plan "richtig" oder "FALSCH" und überspringt Pläne, deren Prüfpunkt noch nicht gebaut ist.

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
| entwurf/01_A4_fehler.pdf | Entwurf | Bei allen Räumen fehlt die Flächenangabe im Raumstempel | ja, alle 9 Räume |
| entwurf/01_A4_fehler.pdf | Entwurf | **Zusätzlich fehlt versehentlich die Höhenangabe ±0,00** neben dem Flur. Das gilt als bekannter Zusatzfehler und zugleich als Fehlerfall für A7 (Höhenangaben). Im Testlauf zählt A7 dort nicht als falscher Alarm. | noch nicht (A7 ungebaut) |

| entwurf/03_A3_fehler.pdf | Entwurf | Bei allen Räumen fehlt der Raumname, die Flächen stehen noch da | ja, alle 9 Flächen ohne Namen |

**Noch gebraucht für A3K (Raum ohne Name und Fläche, KI):** ein Plan `04_A3K_fehler.pdf`, bei dem bei **einem** Raum der komplette Raumstempel (Name und Fläche) gelöscht ist, sonst alles in Ordnung. Dieser Plan wird im Testlauf übersprungen, weil er die echte KI bräuchte. Er wird von Hand in der App mit eingeschalteter KI geprüft.

Hinweis zur Fläche im Raumstempel: Es zählt die Zahl mit Quadratmeter-Einheit (zum Beispiel `22,50 m²`). Ob davor `NGF:` steht, ist egal.

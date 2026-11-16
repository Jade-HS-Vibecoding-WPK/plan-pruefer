# Umsetzungsplan: Planprüfer

Das Seminar dauert 5 Tage. Die Etappen sind an die Kurstage gekoppelt. Grundlage ist die Idee in der [README](README.md).

Leitregel: Jeden Tag muss etwas Lauffähiges stehen. Lieber eine kleine Version, die funktioniert, als eine große, die nicht fertig wird.

| Tag | Etappe | Ziel am Ende des Tages |
|-----|--------|------------------------|
| Mo | Idee & Plan | PLAN.md steht |
| Di | Grundgerüst & Aussehen | Die Web-App läuft und sieht nach uns aus |
| Mi | Daten | Echte Daten von außen sind angebunden |
| Do | Fertig & veröffentlichen | Link oder Datei, 12 Uhr Freeze |
| Fr | Polieren & präsentieren | Wir zeigen, was entstanden ist |

---

## Montag: Idee & Plan

**Ziel:** PLAN.md steht.

- [x] Idee geklärt und in der README zusammengefasst
- [x] Umsetzungsplan in PLAN.md geschrieben
- [x] Umfang für die Woche festlegen (siehe "Umfang: klein anfangen, dann ausbauen")
- [x] Git einrichten (GitHub Desktop)
- [ ] Zwei bis drei echte Beispielpläne (PDF) in den Ordner `testplaene/` legen (ein sauberer Plan, ein Plan mit absichtlichen Fehlern)

**Fertig, wenn:** Alle im Team wissen, was bis Freitag entstehen soll.

---

## Dienstag: Grundgerüst & Aussehen

**Ziel:** Es läuft und sieht nach uns aus.

- [x] Web-App-Grundgerüst aufsetzen, die sich im Browser öffnen lässt (schon am Montag, Start per `Planpruefer-starten.cmd`)
- [x] Seite zum Hochladen von PDF-Dateien
- [x] Befundliste (der Testlauf mit der Plankopf-Prüfung liegt jetzt im Archiv, siehe `archiv/plankopf/`)
- [ ] Aussehen festlegen: Farben, Schrift, Logo, Name "Planprüfer" (erste Fassung steht, Feinschliff offen)
- [x] Ampelfarben für die Befunde (grün = vorhanden, rot = fehlt, grau = korrigiert)

**Fertig, wenn:** Man kann eine PDF hochladen und sieht eine (noch gespielte) Befundliste in unserem Design.

---

## Mittwoch: Daten

**Ziel:** Echte Daten von außen.

- [x] Hochgeladene PDFs wirklich einlesen (Text samt Position, gemeinsamer PDF-Leser in `pruefung/pdf-text.ps1`)
- [ ] Prüfliste der Hochschule (Abgabekriterien) in `unterlagen/` ablegen und die Kriterien für Grundrisse herausfiltern
- [ ] Prüfpunkte der Gruppe A nacheinander bauen, jeweils mit Test (Reihenfolge in [PRUEFKATALOG.md](PRUEFKATALOG.md)): Raumflächen, Höhenangaben, Raumbezeichnungen, Schnittlinien, Nordpfeil, Flächenplausibilität, Bemaßung
- [ ] KI (Google Gemini, kostenlos) als austauschbaren Baustein anbinden, zuerst für den Nordpfeil
- [ ] Befundliste mit echten Ergebnissen füllen, Befunde lassen sich abhaken

**Fertig, wenn:** Ein echter Beispielplan wird geprüft und liefert echte Befunde.

---

## Donnerstag: Fertig & veröffentlichen

**Ziel:** Link oder Datei zum Abgeben. **Freeze um 12 Uhr**, spätestens 18 Uhr.

Vormittag bis 12 Uhr:
- [ ] Abgleich mehrerer Pläne untereinander (Maßstab, Plannummern, Angaben)
- [ ] Markierungen im Plan, falls der Umfang es zulässt
- [ ] Mit allen Beispielplänen testen und Fehler beheben
- [ ] Web-App veröffentlichen, damit es einen Link gibt (oder Datei zum Abgeben vorbereiten)
- [ ] **12 Uhr: Freeze.** Danach keine neuen Funktionen mehr.

Nachmittag (nach dem Freeze):
- [ ] Poster vorbereiten: Idee, Screenshot, was die App kann, was nicht
- [ ] Kurze Demo üben
- [ ] Spätestens 18 Uhr: Link oder Datei abgegeben

**Fertig, wenn:** Die App ist erreichbar und eingefroren, das Poster liegt bereit.

---

## Freitag: Polieren & präsentieren

**Ziel:** Zeigen, was entstanden ist.

- [ ] Nur Kleinigkeiten polieren (Texte, Layout, Rechtschreibung), keine neuen Funktionen
- [ ] Demo mit einem Beispielplan durchspielen, auch ein Plan mit Absicht eingebauten Fehlern
- [ ] README und PLAN.md auf den aktuellen Stand bringen
- [ ] Präsentieren: Idee, Demo, was funktioniert, was als Nächstes käme

---

## Umfang: klein anfangen, dann ausbauen

Wir starten mit der kleinsten sinnvollen Version und bauen in Stufen aus. Jede Stufe läuft für sich, bevor die nächste beginnt.

| Stufe | Was wird geprüft | Technik |
|-------|------------------|---------|
| 0 (erledigt) | Testlauf: Plankopf-Angaben. Er hat gezeigt, wie das Auslesen funktioniert, und ist jetzt im Archiv (`archiv/plankopf/`), weil Planköpfe zu individuell sind | feste Regeln |
| 1 (Start) | **Gruppe A, nur Grundrisse:** Raumflächen, Höhenangaben, Raumbezeichnungen, Schnittlinien, Nordpfeil (nur vorhanden), Flächenplausibilität, Bemaßung. Ergebnis als abhakbare Befundliste | feste Regeln + KI (Gemini, kostenlos) |
| 2 | Markierungen direkt im Plan an der Stelle des Befunds | |
| 3 | **Gruppe B und C:** Maße und Vorschriften (Türen, Flure, Fluchtwege), Rechenwerte. Dafür eventuell IFC statt PDF | feste Regeln + KI |
| 4 | **Gruppe D:** Mehrere Pläne (Plansatz) abgleichen, Vollständigkeit des Plansatzes, Hochschulkriterien | feste Regeln |

Alle Prüfpunkte und ihre Details stehen in [PRUEFKATALOG.md](PRUEFKATALOG.md).

Testplan: Die Beispielpläne liegen im Ordner `testplaene/` (nicht im Git, siehe dort die LIESMICH.md). Für jeden Prüfpunkt testen wir mit einem sauberen Plan und einem Plan mit absichtlich eingebautem Fehler.

## Abspecken, falls es eng wird

Der Umfang "ganzer Plansatz mit Markierungen im Plan" ist groß. Wenn am Mittwochabend klar ist, dass es nicht reicht, streichen wir in dieser Reihenfolge:

1. **Markierungen im Plan** entfallen, es bleibt die abhakbare Befundliste.
2. **Abgleich über mehrere Pläne** entfällt, es wird ein Plan nach dem anderen geprüft.
3. **Weniger Prüfregeln**: Nur die einfachen Prüfpunkte der Gruppe A (Raumflächen, Höhenangaben, Raumbezeichnungen), dafür sauber. Die Bemaßung ist am schwierigsten und kommt zuletzt.

## Risiken

- **KI ist nicht immer zuverlässig.** Befunde der KI werden als Hinweis gekennzeichnet, nicht als sicheres Urteil.
- **PDFs sind unterschiedlich.** Unsere Pläne sind aus ArchiCAD exportierte PDFs und enthalten daher meist echten Text, der sich direkt auslesen lässt. Gescannte Pläne wären deutlich schwieriger und gehören nicht zum Umfang. Wir testen früh mit echten Plänen. Geprüft: Der Text im Musterplan lässt sich markieren und kopieren, ist also auslesbar.
- **Bauordnung und Normen sind umfangreich.** Wir bilden nur eine kleine Auswahl ab und sagen das offen.
- **Wir können wenig programmieren.** Wir arbeiten mit Claude Code, geben kleine Aufgaben und testen jeden Schritt, bevor der nächste kommt.

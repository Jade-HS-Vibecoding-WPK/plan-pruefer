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

- [ ] Web-App-Grundgerüst aufsetzen, die sich im Browser öffnen lässt
- [ ] Seite zum Hochladen von PDF-Dateien
- [ ] Platzhalter für die Befundliste (zunächst mit Beispieltexten)
- [ ] Aussehen festlegen: Farben, Schrift, Logo, Name "Planprüfer"
- [ ] Ampelfarben für die Befunde (ok, Warnung, Fehler)

**Fertig, wenn:** Man kann eine PDF hochladen und sieht eine (noch gespielte) Befundliste in unserem Design.

---

## Mittwoch: Daten

**Ziel:** Echte Daten von außen.

- [ ] Hochgeladene PDFs wirklich einlesen (Text und Zahlen auslesen)
- [ ] Prüfliste der Hochschule (Abgabekriterien) in eine maschinenlesbare Form bringen
- [ ] Ausgewählte Regeln aus der Bauordnung und den Normen erfassen (zum Beispiel Mindestbreiten von Türen und Fluren)
- [ ] Erste feste Regeln umsetzen: Plankopf-Angaben vorhanden? Projektname, Projektort (Straße, Ort, PLZ), Bauherr, Maßstab, Datum, Planer, Plannummer?
- [ ] KI anbinden für alles, was Verständnis braucht (zum Beispiel: Ist ein Nordpfeil im Plan?)
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
| 1 (Start) | **Ein Grundriss**, nur **Plankopf**. Geprüft wird, ob diese Angaben vorhanden sind: Projektname, Projektort (Straße, Ort und Postleitzahl), Bauherr, Maßstab, Datum, Planer, Plannummer. Ergebnis als abhakbare Befundliste. | feste Regeln |
| 2 | Pflichtbestandteile im Plan: Nordpfeil, Maßketten, Raumbezeichnungen, Legende | feste Regeln + KI |
| 3 | Mehrere Pläne (Plansatz): Angaben über alle Pläne abgleichen, vorhandene Planarten | feste Regeln |
| 4 | Normen und Bauordnung (Türen, Flure, Fluchtwege), Rechenwerte | feste Regeln + KI |
| 5 | Markierungen direkt im Plan | |

Testplan: Die Beispielpläne liegen im Ordner `testplaene/` (nicht im Git, siehe dort die LIESMICH.md). Für jede Stufe testen wir mit einem sauberen Plan und einem Plan mit absichtlich eingebauten Fehlern.

## Abspecken, falls es eng wird

Der Umfang "ganzer Plansatz mit Markierungen im Plan" ist groß. Wenn am Mittwochabend klar ist, dass es nicht reicht, streichen wir in dieser Reihenfolge:

1. **Markierungen im Plan** entfallen, es bleibt die abhakbare Befundliste.
2. **Abgleich über mehrere Pläne** entfällt, es wird ein Plan nach dem anderen geprüft.
3. **Weniger Prüfregeln**: Nur Plankopf und eine Handvoll Normen (Türen, Flure), dafür sauber.

## Risiken

- **KI ist nicht immer zuverlässig.** Befunde der KI werden als Hinweis gekennzeichnet, nicht als sicheres Urteil.
- **PDFs sind unterschiedlich.** Unsere Pläne sind aus ArchiCAD exportierte PDFs und enthalten daher meist echten Text, der sich direkt auslesen lässt. Gescannte Pläne wären deutlich schwieriger und gehören nicht zum Umfang. Wir testen früh mit echten Plänen. Geprüft: Der Text im Musterplan lässt sich markieren und kopieren, ist also auslesbar.
- **Bauordnung und Normen sind umfangreich.** Wir bilden nur eine kleine Auswahl ab und sagen das offen.
- **Wir können wenig programmieren.** Wir arbeiten mit Claude Code, geben kleine Aufgaben und testen jeden Schritt, bevor der nächste kommt.

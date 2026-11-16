# plan-pruefer

Ein Tool, das Baupläne auf Vollständigkeit und Richtigkeit prüft

## Idee

Der Planprüfer ist eine Web-App für Architekturstudierende. Man lädt einen kompletten Plansatz als PDF-Dateien hoch und bekommt eine Prüfung zurück.

### Was die erste Version können soll

**Eingabe**
- Ein ganzer Plansatz (mehrere PDFs, zum Beispiel Grundrisse, Schnitte und Ansichten), der auch untereinander abgeglichen wird.

**Prüfung auf Vollständigkeit**
- Pflichtangaben im Plankopf (Projektname, Projektort mit Straße, Ort und Postleitzahl, Bauherr, Maßstab, Datum, Planer, Plannummer)
- Pflichtbestandteile im Plan (zum Beispiel Nordpfeil, Maßketten, Raumbezeichnungen, Legende)
- Vorhandene Planarten (sind alle nötigen Pläne im Satz enthalten?)

**Prüfung auf Richtigkeit**
- Stimmigkeit der Angaben (passen Maßstab, Maße und Plannummern über alle Pläne zusammen?)
- Normen und Vorschriften (zum Beispiel Mindestbreiten von Türen und Fluren, Fluchtwege)
- Rechenwerte (zum Beispiel Flächen und Volumen werden nachgerechnet)

**Gegen welche Anforderungen wird geprüft?**
- Abgabekriterien der Hochschule
- Bauordnung und zugehörige Normen

**Ergebnis**
- Eine Liste mit Befunden, die man abhaken kann, sobald der Fehler korrigiert ist.
- Markierungen direkt im Plan an der Stelle des Befunds.

**Technik (grob)**
- Eine Mischung aus festen Regeln (für alles Eindeutige, zum Beispiel Text und Zahlen vergleichen) und KI (für alles, was Verständnis des Plans braucht).

### Offene Punkte

- Der Umfang "ganzer Plansatz" mit Markierungen im Plan ist für eine erste Version ziemlich groß. Falls es zu aufwendig wird, wäre ein Start mit nur Grundrissen und einer reinen Befundliste ein sinnvoller Zwischenschritt.
- Welche Bauordnung (Bundesland) genau gilt, ist noch nicht festgelegt.
- Die konkreten Prüfkriterien der Hochschule müssen noch gesammelt werden.
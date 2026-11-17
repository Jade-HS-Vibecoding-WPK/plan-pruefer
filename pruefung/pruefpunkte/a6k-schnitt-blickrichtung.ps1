<#
  A6K Schnittlinien im Bild (mit KI)

  Eine Schnittlinie ist eine Strich-Punkt-Linie durch den Grundriss. An beiden Enden steht ein ausgefülltes
  Dreieck, beide Dreiecke zeigen in dieselbe Richtung (das ist die Blickrichtung). Eine Beschriftung mit Buchstaben
  ist möglich, aber nicht nötig. Das alles ist Zeichnung und steht nicht im PDF-Text, deshalb schaut hier eine KI
  (Google Gemini) den Plan als Bild an.

  Geprüft wird:
    1. Es gibt mindestens eine Schnittlinie.
    2. Jede Schnittlinie hat an beiden Enden ein Dreieck.
    3. Beide Dreiecke einer Schnittlinie zeigen in dieselbe Richtung.

  - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
  - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
  - Die Beschriftung mit Buchstaben prüft A6 ohne KI.
#>

$script:A6K_Frage = @'
Das Bild zeigt einen Grundriss (ArchiCAD-Export). Prüfe die Schnittlinien.

Eine Schnittlinie ist eine meist strichpunktierte Linie, die durch den Grundriss läuft. An BEIDEN Enden der Linie steht ein ausgefülltes Dreieck (manchmal ein Pfeil), und beide Dreiecke zeigen in DIESELBE Richtung: das ist die Blickrichtung des Schnitts. Oft steht an den Enden zusätzlich ein Buchstabe (zum Beispiel "A"), das ist aber nicht nötig. Achsen und Maßketten sind keine Schnittlinien.

Aufgaben:
1. anzahl_schnittlinien: Zähle alle Schnittlinien im Plan.
2. probleme: Nenne jede Schnittlinie, bei der etwas nicht stimmt. Es gibt zwei Problemarten:
   - "dreieck_fehlt": an einem Ende oder an beiden Enden steht kein Dreieck (kein Pfeil).
   - "richtung_unterschiedlich": die beiden Dreiecke zeigen in unterschiedliche Richtungen (zum Beispiel eines nach oben, das andere nach unten).

Regeln:
- Schnittlinien, bei denen alles stimmt, gehören NICHT in die Liste probleme.
- Wenn du dir bei einer Schnittlinie nicht sicher bist, nimm sie NICHT in probleme auf.
- Beschreibe die Lage jeder Schnittlinie im Problem so, dass man sie im Plan findet, und gib die ungefähre Mitte in Prozent der Seitenbreite (x, von links) und der Seitenhöhe (y, von oben) an.
'@

$script:A6K_Schema = @{
    type       = 'object'
    properties = @{
        anzahl_schnittlinien = @{ type = 'integer'; description = 'Anzahl der Schnittlinien im Plan' }
        probleme             = @{
            type  = 'array'
            items = @{
                type       = 'object'
                properties = @{
                    problem     = @{ type = 'string'; enum = @('dreieck_fehlt', 'richtung_unterschiedlich') }
                    bezeichnung = @{ type = 'string'; description = 'Bezeichnung der Schnittlinie, zum Beispiel A, leer wenn keine' }
                    lage        = @{ type = 'string'; description = 'Lage der Schnittlinie im Plan in Worten' }
                    x_prozent   = @{ type = 'number'; description = 'Mitte, Prozent der Seitenbreite von links' }
                    y_prozent   = @{ type = 'number'; description = 'Mitte, Prozent der Seitenhöhe von oben' }
                }
                required   = @('problem', 'lage')
            }
        }
    }
    required   = @('anzahl_schnittlinien', 'probleme')
}

# Wandelt die Antwort der KI in Ergebnisse um (getrennt vom Aufruf, damit es ohne echte KI getestet werden kann).
function ConvertTo-A6KErgebnisse($antwort) {
    # Hat die KI nicht die vorgegebene Struktur geliefert, darf das nie als "keine Funde" durchgehen.
    if ($null -eq $antwort -or -not ($antwort.PSObject.Properties.Name -contains 'anzahl_schnittlinien') -or -not ($antwort.PSObject.Properties.Name -contains 'probleme')) {
        throw "Die KI-Antwort hatte nicht die erwartete Struktur (Felder 'anzahl_schnittlinien' und 'probleme' fehlen)."
    }
    if ([int]$antwort.anzahl_schnittlinien -le 0) {
        $e = New-Result 'Schnittlinie' $false '' 'KI-Hinweis, bitte prüfen: Im Plan wurde keine Schnittlinie gefunden (gesucht: Strich-Punkt-Linie mit zwei Dreiecken).'
        $e.Quelle = 'ki'
        $e
    }
    foreach ($s in @($antwort.probleme)) {
        if ($null -eq $s) { continue }
        $name = if ($s.bezeichnung) { "Schnitt $($s.bezeichnung)" } else { 'Schnittlinie' }
        $lage = if ($s.lage) { [string]$s.lage } else { 'Lage unbekannt' }
        $pos = ''
        if ($null -ne $s.x_prozent -and $null -ne $s.y_prozent) { $pos = " (ungefähr $([math]::Round([double]$s.x_prozent)) % von links, $([math]::Round([double]$s.y_prozent)) % von oben)" }
        $text = if ($s.problem -eq 'richtung_unterschiedlich') { 'Die beiden Dreiecke zeigen in unterschiedliche Richtungen.' } else { 'An mindestens einem Ende fehlt das Dreieck für die Blickrichtung.' }
        $e = New-Result $name $false '' "KI-Hinweis, bitte prüfen: $lage$pos. $text"
        $e.Quelle = 'ki'
        $e
    }
}

function Get-A6KSchnitte($pdfPfad, $bildPfad) {
    $datei = if ($bildPfad -and (Test-Path $bildPfad)) { $bildPfad } else { $pdfPfad }
    $antwort = Invoke-KiPdfFrage $datei $script:A6K_Frage $script:A6K_Schema
    ConvertTo-A6KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A6K'
    Name   = 'Schnittlinien im Bild (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A6KSchnitte $pdfPfad $bildPfad }
}

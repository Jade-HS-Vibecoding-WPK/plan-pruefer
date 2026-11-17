<#
  A7K Höhenangabe an Raumebenen (mit KI)

  Wechselt im Grundriss die Höhenlage des Fußbodens (Stufen, Podeste, abgesenkte oder erhöhte Bereiche),
  muss an dieser Ebene eine eigene Höhenkote stehen. Das lässt sich aus dem PDF-Text nicht erkennen, deshalb
  schaut hier eine KI (Google Gemini) den Plan an.

  - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
  - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
  - Dass es überhaupt eine Höhenkote im Plan gibt, prüft A7 ohne KI.
#>

function Get-A7KFrage($koten) {
    $liste = if (@($koten).Count -gt 0) { "Laut Text des Plans stehen diese Höhenkoten im Plan: $(@($koten) -join '; ')." } else { 'Laut Text des Plans steht keine Höhenkote im Plan.' }
    @"
Das Bild zeigt einen Grundriss (ArchiCAD-Export). Du prüfst ihn auf Höhenangaben. Höhenkoten stehen als Zahl mit Vorzeichen im Plan, zum Beispiel ±0,00, +0,15 oder -0,30. $liste

Einen Ebenenwechsel (Stufe, Podest, abgesenkter oder erhöhter Bereich) erkennt man an einer DURCHGEHENDEN LINIE MITTEN IN EINEM RAUM, die den Raum in zwei Bereiche teilt. Es ist keine Wand (keine Schraffur, keine dicke Wandkontur), kein Möbelstück und keine Maßlinie. Jeder der beiden Bereiche beiderseits der Linie braucht eine eigene Höhenkote.

Suche solche Linien im Plan. Gib NUR die Bereiche zurück, an denen die Ebene wechselt UND auf mindestens einer Seite der Linie keine eigene Höhenkote steht.

Regeln:
- Linien, bei denen beide Seiten eine Höhenkote haben, gehören NICHT in die Liste.
- Treppen, die in ein anderes Geschoss führen, gelten nicht als Ebenenwechsel in diesem Plan.
- Wenn du dir nicht sicher bist, ob die Linie einen Ebenenwechsel zeigt, nimm sie NICHT auf.
- Beschreibe die Lage so, dass eine Person den Bereich im Plan findet (zum Beispiel "oben im Flur, quer zur Eingangstür").
- Gib die ungefähre Mitte der Linie als Prozentwerte der Seitenbreite (x, 0 = links) und der Seitenhöhe (y, 0 = oben) an.
- Gibt es keinen solchen Bereich, antworte mit einer leeren Liste.
"@
}

# Höhenkoten aus dem PDF-Text mit ungefährer Lage (Prozent der Seite), als Hilfe für die KI.
function Get-A7KBekannteKoten($items, $pdfPfad) {
    $seite = Get-PdfSeitengroesse $pdfPfad
    foreach ($p in $items) {
        if ($p.T -match $script:A7_HoehenkoteMitOK -or $p.T -match $script:A7_Hoehenkote) {
            "$($Matches['h'].Trim()) (ca. $([math]::Round(100 * $p.X / $seite.Breite)) % von links, $([math]::Round(100 * $p.Y / $seite.Hoehe)) % von oben)"
        }
    }
}

$script:A7K_Schema = @{
    type       = 'object'
    properties = @{
        bereiche = @{
            type  = 'array'
            items = @{
                type       = 'object'
                properties = @{
                    art       = @{ type = 'string'; description = 'Art des Ebenenwechsels, zum Beispiel Stufe, Podest, abgesenkt, erhöht' }
                    lage      = @{ type = 'string'; description = 'Lage des Bereichs im Plan in Worten' }
                    x_prozent = @{ type = 'number'; description = 'Mitte, Prozent der Seitenbreite von links' }
                    y_prozent = @{ type = 'number'; description = 'Mitte, Prozent der Seitenhöhe von oben' }
                }
                required   = @('lage')
            }
        }
    }
    required   = @('bereiche')
}

# Wandelt die Antwort der KI in Ergebnisse um (getrennt vom Aufruf, damit es ohne echte KI getestet werden kann).
function ConvertTo-A7KErgebnisse($antwort) {
    # Hat die KI nicht die vorgegebene Struktur geliefert, darf das nie als "keine Funde" durchgehen.
    if ($null -eq $antwort -or -not ($antwort.PSObject.Properties.Name -contains 'bereiche')) {
        throw "Die KI-Antwort hatte nicht die erwartete Struktur (Feld 'bereiche' fehlt)."
    }
    foreach ($b in @($antwort.bereiche)) {
        if ($null -eq $b) { continue }
        $lage = if ($b.lage) { [string]$b.lage } else { 'Lage unbekannt' }
        $art = if ($b.art) { [string]$b.art } else { 'Ebenenwechsel' }
        $pos = ''
        if ($null -ne $b.x_prozent -and $null -ne $b.y_prozent) { $pos = " (ungefähr $([math]::Round([double]$b.x_prozent)) % von links, $([math]::Round([double]$b.y_prozent)) % von oben)" }
        $e = New-Result 'Höhenangabe an Raumebene' $false '' "KI-Hinweis, bitte prüfen: $art, $lage$pos. Die Ebene wechselt, aber es steht keine eigene Höhenkote dabei."
        $e.Quelle = 'ki'
        $e
    }
}

function Get-A7KBereiche($items, $pdfPfad, $bildPfad) {
    $datei = if ($bildPfad -and (Test-Path $bildPfad)) { $bildPfad } else { $pdfPfad }
    $koten = @(Get-A7KBekannteKoten $items $pdfPfad)
    $antwort = Invoke-KiPdfFrage $datei (Get-A7KFrage $koten) $script:A7K_Schema
    ConvertTo-A7KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A7K'
    Name   = 'Höhenangabe an Raumebenen (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A7KBereiche $items $pdfPfad $bildPfad }
}

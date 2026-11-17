<#
  A7K Höhenangabe an Raumebenen (mit KI)

  Wechselt im Grundriss die Höhenlage des Fußbodens (Stufen, Podeste, abgesenkte oder erhöhte Bereiche),
  muss an dieser Ebene eine eigene Höhenkote stehen. Das lässt sich aus dem PDF-Text nicht erkennen, deshalb
  schaut hier eine KI (Google Gemini) den Plan an.

  - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
  - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
  - Dass es überhaupt eine Höhenkote im Plan gibt, prüft A7 ohne KI.
#>

$script:A7K_Frage = @'
Das Bild zeigt einen Grundriss (ArchiCAD-Export). Du prüfst ihn auf Höhenangaben. Höhenkoten stehen als Zahl mit Vorzeichen im Plan, zum Beispiel ±0,00, +0,15 oder -0,30.

Suche Bereiche im Plan, in denen die Höhenlage des Fußbodens wechselt: Stufen, Podeste, abgesenkte oder erhöhte Bereiche (zum Beispiel ein Eingang mit Stufe, ein abgesenktes Bad, eine Terrasse unter oder über dem Fußbodenniveau).

Gib NUR die Bereiche zurück, bei denen die Ebene wechselt UND keine eigene Höhenkote eingezeichnet ist.

Regeln:
- Bereiche, bei denen eine Höhenkote steht, gehören NICHT in die Liste.
- Treppen, die in ein anderes Geschoss führen, gelten nicht als Ebenenwechsel in diesem Plan.
- Wenn du dir nicht sicher bist, ob die Ebene wechselt, nimm den Bereich NICHT auf.
- Beschreibe die Lage so, dass eine Person den Bereich im Plan findet (zum Beispiel "rechts unten, Eingang mit zwei Stufen").
- Gib die ungefähre Mitte als Prozentwerte der Seitenbreite (x, 0 = links) und der Seitenhöhe (y, 0 = oben) an.
- Gibt es keinen solchen Bereich, antworte mit einer leeren Liste.
'@

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

function Get-A7KBereiche($pdfPfad, $bildPfad) {
    $datei = if ($bildPfad -and (Test-Path $bildPfad)) { $bildPfad } else { $pdfPfad }
    $antwort = Invoke-KiPdfFrage $datei $script:A7K_Frage $script:A7K_Schema
    ConvertTo-A7KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A7K'
    Name   = 'Höhenangabe an Raumebenen (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A7KBereiche $pdfPfad $bildPfad }
}

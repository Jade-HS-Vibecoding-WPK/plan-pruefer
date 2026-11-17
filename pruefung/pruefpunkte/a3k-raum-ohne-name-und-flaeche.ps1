<#
  A3K Raum ohne Name und Fläche (mit KI)

  Ein Raum, bei dem weder Name noch Fläche im Plan stehen, hinterlässt im PDF keinen Text. Deshalb schaut hier
  eine KI (Google Gemini) den Plan an und meldet Räume ohne Beschriftung.

  - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
  - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
  - Räume, bei denen wenigstens Name ODER Fläche vorhanden ist, prüfen A3 und A4 ohne KI.
#>

$script:A3K_Frage = @'
Du prüfst einen Grundriss (ArchiCAD-Export) auf formale Vollständigkeit. In diesem Plan hat jeder Raum normalerweise einen Raumstempel mit dem Raumnamen und darunter der Fläche in m².

Suche alle Räume (von Wänden umschlossene Bereiche im Gebäude, auch Nebengebäude wie Carport oder Gartenhaus), bei denen WEDER ein Raumname NOCH eine Flächenangabe im Plan steht.

Regeln:
- Räume, bei denen mindestens eines von beiden (Name oder Fläche) vorhanden ist, gehören NICHT in die Liste.
- Ignoriere Treppen, Schächte, Wandstärken, Flächen außerhalb des Gebäudes und offene Terrassen.
- Wenn du dir nicht sicher bist, ob ein Bereich ein Raum ist, nimm ihn NICHT auf.
- Beschreibe für jeden gefundenen Raum die Lage so, dass eine Person ihn im Plan findet (zum Beispiel "links oben, neben dem Raum Flur").
- Gib die ungefähre Mitte des Raums als Prozentwerte der Seitenbreite (x, 0 = links) und der Seitenhöhe (y, 0 = oben) an.
- Gibt es keinen solchen Raum, antworte mit einer leeren Liste.
'@

$script:A3K_Schema = @{
    type       = 'object'
    properties = @{
        raeume = @{
            type  = 'array'
            items = @{
                type       = 'object'
                properties = @{
                    lage     = @{ type = 'string'; description = 'Lage des Raums im Plan in Worten' }
                    x_prozent = @{ type = 'number'; description = 'Mitte des Raums, Prozent der Seitenbreite von links' }
                    y_prozent = @{ type = 'number'; description = 'Mitte des Raums, Prozent der Seitenhöhe von oben' }
                }
                required   = @('lage')
            }
        }
    }
    required   = @('raeume')
}

# Wandelt die Antwort der KI in Ergebnisse um (getrennt vom Aufruf, damit es ohne echte KI getestet werden kann).
function ConvertTo-A3KErgebnisse($antwort) {
    # Hat die KI nicht die vorgegebene Struktur geliefert, darf das nie als "keine Funde" durchgehen.
    if ($null -eq $antwort -or -not ($antwort.PSObject.Properties.Name -contains 'raeume')) {
        throw "Die KI-Antwort hatte nicht die erwartete Struktur (Feld 'raeume' fehlt)."
    }
    foreach ($r in @($antwort.raeume)) {
        if ($null -eq $r) { continue }
        $lage = if ($r.lage) { [string]$r.lage } else { 'Lage unbekannt' }
        $pos = ''
        if ($null -ne $r.x_prozent -and $null -ne $r.y_prozent) { $pos = " (ungefähr $([math]::Round([double]$r.x_prozent)) % von links, $([math]::Round([double]$r.y_prozent)) % von oben)" }
        $e = New-Result 'Raum ohne Name und Fläche' $false '' "KI-Hinweis, bitte prüfen: $lage$pos. Weder Raumname noch Fläche gefunden."
        $e.Quelle = 'ki'
        $e
    }
}

function Get-A3KRaeume($pdfPfad) {
    $antwort = Invoke-KiPdfFrage $pdfPfad $script:A3K_Frage $script:A3K_Schema
    ConvertTo-A3KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A3K'
    Name   = 'Raum ohne Name und Fläche (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad) Get-A3KRaeume $pdfPfad }
}

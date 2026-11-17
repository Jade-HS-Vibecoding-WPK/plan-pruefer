<#
  A6K Schnittlinien: Blickrichtung (mit KI)

  Jede Schnittlinie muss eine Blickrichtung zeigen, meist ein ausgefülltes Dreieck oder ein Pfeil am Ende der
  Linie. Das ist Zeichnung und steht nicht im PDF-Text, deshalb schaut hier eine KI (Google Gemini) den Plan an.

  - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
  - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
  - Dass Schnittlinien vorhanden und an beiden Enden beschriftet sind, prüft A6 ohne KI.
#>

$script:A6K_Frage = @'
Du prüfst einen Grundriss (ArchiCAD-Export) auf die Darstellung der Schnittlinien. Eine Schnittlinie ist eine meist strichpunktierte Linie durch den Grundriss, die an den Enden mit einer Bezeichnung (zum Beispiel "A") beschriftet ist. Die Blickrichtung des Schnitts wird durch ein ausgefülltes Dreieck oder einen Pfeil an einem oder an beiden Enden gezeigt.

Suche alle Schnittlinien und prüfe für jede, ob die Blickrichtung angegeben ist.

Gib NUR die Schnittlinien zurück, bei denen KEINE Blickrichtung (kein Dreieck, kein Pfeil) zu sehen ist.

Regeln:
- Schnittlinien, bei denen die Blickrichtung angegeben ist, gehören NICHT in die Liste.
- Achsen und Maßketten sind keine Schnittlinien.
- Wenn du dir nicht sicher bist, ob die Blickrichtung fehlt, nimm die Schnittlinie NICHT auf.
- Gib die Bezeichnung der Schnittlinie an (zum Beispiel "A"), beschreibe die Lage in Worten und gib die ungefähre Mitte als Prozentwerte der Seitenbreite (x, 0 = links) und der Seitenhöhe (y, 0 = oben) an.
- Gibt es keine Schnittlinie ohne Blickrichtung, antworte mit einer leeren Liste.
'@

$script:A6K_Schema = @{
    type       = 'object'
    properties = @{
        schnitte = @{
            type  = 'array'
            items = @{
                type       = 'object'
                properties = @{
                    bezeichnung = @{ type = 'string'; description = 'Bezeichnung der Schnittlinie, zum Beispiel A' }
                    lage        = @{ type = 'string'; description = 'Lage der Schnittlinie im Plan in Worten' }
                    x_prozent   = @{ type = 'number'; description = 'Mitte, Prozent der Seitenbreite von links' }
                    y_prozent   = @{ type = 'number'; description = 'Mitte, Prozent der Seitenhöhe von oben' }
                }
                required   = @('lage')
            }
        }
    }
    required   = @('schnitte')
}

# Wandelt die Antwort der KI in Ergebnisse um (getrennt vom Aufruf, damit es ohne echte KI getestet werden kann).
function ConvertTo-A6KErgebnisse($antwort) {
    # Hat die KI nicht die vorgegebene Struktur geliefert, darf das nie als "keine Funde" durchgehen.
    if ($null -eq $antwort -or -not ($antwort.PSObject.Properties.Name -contains 'schnitte')) {
        throw "Die KI-Antwort hatte nicht die erwartete Struktur (Feld 'schnitte' fehlt)."
    }
    foreach ($s in @($antwort.schnitte)) {
        if ($null -eq $s) { continue }
        $name = if ($s.bezeichnung) { [string]$s.bezeichnung } else { '' }
        $lage = if ($s.lage) { [string]$s.lage } else { 'Lage unbekannt' }
        $pos = ''
        if ($null -ne $s.x_prozent -and $null -ne $s.y_prozent) { $pos = " (ungefähr $([math]::Round([double]$s.x_prozent)) % von links, $([math]::Round([double]$s.y_prozent)) % von oben)" }
        $titel = if ($name) { "Schnitt $name ohne Blickrichtung" } else { 'Schnittlinie ohne Blickrichtung' }
        $e = New-Result $titel $false '' "KI-Hinweis, bitte prüfen: $lage$pos. Es ist kein Dreieck oder Pfeil als Blickrichtung zu sehen."
        $e.Quelle = 'ki'
        $e
    }
}

function Get-A6KSchnitte($pdfPfad) {
    $antwort = Invoke-KiPdfFrage $pdfPfad $script:A6K_Frage $script:A6K_Schema
    ConvertTo-A6KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A6K'
    Name   = 'Schnitt-Blickrichtung (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad) Get-A6KSchnitte $pdfPfad }
}

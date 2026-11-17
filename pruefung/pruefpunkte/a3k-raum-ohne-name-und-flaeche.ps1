<#
  A3K Raum ohne Name und Fläche (mit KI)

  Ein Raum, bei dem weder Name noch Fläche im Plan stehen, hinterlässt im PDF keinen Text. Deshalb schaut hier
  eine KI (Google Gemini) den Plan als Bild an und sucht Räume ohne Beschriftung.

  So geht die Prüfung vor:
    - Aus dem PDF-Text sind die beschrifteten Räume schon bekannt (A3/A4). Diese Liste bekommt die KI mit
      und soll nur nach WEITEREN Räumen suchen, die keine Beschriftung haben. Ohne diese Liste zählt die KI
      erfahrungsgemäß nur die beschrifteten Räume auf und übersieht den unbeschrifteten.
    - Läuft nur, wenn die Nutzerin die KI-Prüfung ausdrücklich einschaltet (der Plan wird dabei an Google gesendet).
    - Das Ergebnis ist ein HINWEIS der KI und muss von einem Menschen geprüft werden.
#>

function Get-A3KFrage($bekannteRaeume) {
    $liste = if (@($bekannteRaeume).Count -gt 0) { "In diesem Plan haben die folgenden Räume einen Stempel mit Raumname und Fläche: $(@($bekannteRaeume) -join ', ')." } else { 'In diesem Plan wurde im Text kein Raumstempel mit Raumname und Fläche gefunden.' }
    @"
Das Bild zeigt einen Grundriss (ArchiCAD-Export). $liste

Prüfe jetzt, ob es im Grundriss noch WEITERE von Wänden umschlossene Räume gibt, die in dieser Liste NICHT vorkommen und bei denen kein Raumname und keine Flächenangabe als Text steht. Solche Räume erkennst du an Wänden, Türen, Fenstern, Möbeln oder Treppen, aber ohne Beschriftung. Gehe den ganzen Plan Raum für Raum durch, auch die Ecken.

Gib NUR diese weiteren, unbeschrifteten Räume zurück. Beschreibe die Lage so, dass man den Raum findet (zum Beispiel "oben links, neben dem Flur"), und gib die ungefähre Mitte in Prozent der Seitenbreite (von links) und der Seitenhöhe (von oben) an. Treppen, Schächte, Wandstärken und Flächen außerhalb des Gebäudes sind keine Räume. Gibt es keine solchen Räume, antworte mit einer leeren Liste.
"@
}

$script:A3K_Schema = @{
    type       = 'object'
    properties = @{
        weitere_raeume = @{
            type  = 'array'
            items = @{
                type       = 'object'
                properties = @{
                    lage      = @{ type = 'string'; description = 'Lage des Raums im Plan in Worten' }
                    hinweis   = @{ type = 'string'; description = 'Woran erkennbar ist, dass es ein Raum ist (Türen, Möbel, Wände)' }
                    x_prozent = @{ type = 'number'; description = 'Mitte des Raums, Prozent der Seitenbreite von links' }
                    y_prozent = @{ type = 'number'; description = 'Mitte des Raums, Prozent der Seitenhöhe von oben' }
                }
                required   = @('lage')
            }
        }
    }
    required   = @('weitere_raeume')
}

# Wandelt die Antwort der KI in Ergebnisse um (getrennt vom Aufruf, damit es ohne echte KI getestet werden kann).
function ConvertTo-A3KErgebnisse($antwort) {
    # Hat die KI nicht die vorgegebene Struktur geliefert, darf das nie als "keine Funde" durchgehen.
    if ($null -eq $antwort -or -not ($antwort.PSObject.Properties.Name -contains 'weitere_raeume')) {
        throw "Die KI-Antwort hatte nicht die erwartete Struktur (Feld 'weitere_raeume' fehlt)."
    }
    foreach ($r in @($antwort.weitere_raeume)) {
        if ($null -eq $r) { continue }
        $lage = if ($r.lage) { [string]$r.lage } else { 'Lage unbekannt' }
        $pos = ''
        if ($null -ne $r.x_prozent -and $null -ne $r.y_prozent) { $pos = " (ungefähr $([math]::Round([double]$r.x_prozent)) % von links, $([math]::Round([double]$r.y_prozent)) % von oben)" }
        $e = New-Result 'Raum ohne Name und Fläche' $false '' "KI-Hinweis, bitte prüfen: $lage$pos. Weder Raumname noch Fläche gefunden."
        $e.Quelle = 'ki'
        $e
    }
}

function Get-A3KRaeume($items, $pdfPfad, $bildPfad) {
    $stempel = @(Get-Raumstempel $items)
    $bekannt = @($stempel | Where-Object { $_.NameText } | ForEach-Object { $_.NameText }) + @(Get-RaumnamenOhneFlaeche $items $stempel | ForEach-Object { $_.T })
    $bekannt = @($bekannt | Select-Object -Unique)
    $datei = if ($bildPfad -and (Test-Path $bildPfad)) { $bildPfad } else { $pdfPfad }
    $antwort = Invoke-KiPdfFrage $datei (Get-A3KFrage $bekannt) $script:A3K_Schema
    ConvertTo-A3KErgebnisse $antwort
}

$script:Pruefungen += @{
    Id     = 'A3K'
    Name   = 'Raum ohne Name und Fläche (KI)'
    Phasen = @('entwurf', 'werk')
    Ki     = $true
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A3KRaeume $items $pdfPfad $bildPfad }
}

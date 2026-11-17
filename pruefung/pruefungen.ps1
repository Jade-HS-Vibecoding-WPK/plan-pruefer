<#
  Sammelstelle für alle Prüfpunkte des Planprüfers.

  Jeder Prüfpunkt liegt als eigene Datei im Ordner "pruefpunkte" (zum Beispiel a4-raumflaechen.ps1)
  und trägt sich selbst in die Liste $script:Pruefungen ein:

    $script:Pruefungen += @{
        Id     = 'A4'
        Name   = 'Raumflächen'
        Phasen = @('entwurf', 'werk')
        Ki     = $false                                  # $true = braucht die KI (nur wenn die Nutzerin sie einschaltet)
        Run    = { param($items, $pdfPfad) ... }
    }

  "Phasen" legt fest, für welche Planungsphase der Punkt gilt (die Nutzerin wählt sie vor dem Hochladen):
    'entwurf' = Checkliste Entwurfsplanung (Grundrisse 1:100)
    'werk'    = Checkliste Werkplanung (Grundrisse 1:50)
  "Run" bekommt die Textstücke des Plans (siehe pdf-text.ps1) und den Pfad des PDFs und gibt pro Raum
  oder Angabe ein Ergebnis zurück, erzeugt mit New-Result. Ok = $true heißt: in Ordnung, $false: Befund.
  Neue Prüfpunkte werden automatisch geladen, es muss nichts weiter eingetragen werden.
#>
. "$PSScriptRoot\pdf-text.ps1"
. "$PSScriptRoot\raumstempel.ps1"
. "$PSScriptRoot\ki\gemini.ps1"

# Ein Ergebnis einer Prüfung.
#   angabe  Was geprüft wurde (zum Beispiel "Raum Flur")
#   ok      $true = in Ordnung, $false = Befund
#   wert    Gefundener Wert (zum Beispiel "22,50 m²")
#   detail  Erklärung bei einem Befund
#   x, y    Position im Plan (für die spätere Markierung), optional
# Punkt (Prüfpunkt-Nummer) und Quelle ('' oder 'ki') werden später gesetzt.
function New-Result($angabe, $ok, $wert, $detail, $x = $null, $y = $null) {
    [pscustomobject]@{ Angabe = $angabe; Ok = $ok; Wert = $wert; Detail = $detail; X = $x; Y = $y; Punkt = ''; Quelle = '' }
}

# Aktive Prüfpunkte: alle Dateien aus dem Ordner "pruefpunkte" laden.
$script:Pruefungen = @()
$pruefpunkteOrdner = Join-Path $PSScriptRoot 'pruefpunkte'
if (Test-Path $pruefpunkteOrdner) {
    foreach ($datei in (Get-ChildItem $pruefpunkteOrdner -Filter *.ps1 | Sort-Object Name)) {
        . $datei.FullName
    }
}

# Meldungen an die Nutzerin (zum Beispiel "KI-Prüfung nicht möglich"), keine Befunde im Plan.
$script:Meldungen = @()
function Get-Meldungen { @($script:Meldungen) }

function Get-AktivePruefungen([string]$Phase = 'entwurf', [bool]$MitKi = $false) {
    @($script:Pruefungen | Where-Object { $_.Phasen -contains $Phase -and (-not $_.Ki -or $MitKi) } | ForEach-Object { "$($_.Id) $($_.Name)" })
}

# BildPfad: optional ein PNG-Bild der Planseite. Die KI-Prüfungen nutzen es, weil die KI Zeichnungen nur im Bild
# wirklich sieht (bei einem PDF liest sie vor allem den Text).
function Invoke-Pruefungen([string]$Path, [string]$Phase = 'entwurf', [bool]$MitKi = $false, [string]$BildPfad = '') {
    $script:Meldungen = @()
    $items = @(Get-PdfTextItems $Path)
    if ($items.Count -eq 0) {
        return @(New-Result 'PDF' $false '' 'Kein Text im PDF gefunden (gescannt oder Schrift in Linien umgewandelt).')
    }
    foreach ($p in ($script:Pruefungen | Where-Object { $_.Phasen -contains $Phase })) {
        if ($p.Ki) {
            if (-not $MitKi) { continue }
            if (-not (Test-KiVerfuegbar)) {
                $script:Meldungen += "KI-Prüfung '$($p.Name)' nicht möglich: Es ist kein KI-Schlüssel hinterlegt (siehe README, Abschnitt 'KI-Prüfung einrichten')."
                continue
            }
            try {
                foreach ($r in @(& $p.Run $items $Path $BildPfad)) { if ($null -ne $r) { $r.Punkt = $p.Id; $r } }
            } catch {
                $script:Meldungen += "KI-Prüfung '$($p.Name)' konnte nicht ausgeführt werden: $($_.Exception.Message)"
            }
            continue
        }
        foreach ($r in @(& $p.Run $items $Path $BildPfad)) {
            if ($null -ne $r) { $r.Punkt = $p.Id; $r }
        }
    }
}

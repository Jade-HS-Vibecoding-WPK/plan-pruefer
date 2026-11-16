<#
  Sammelstelle für alle Prüfpunkte des Planprüfers.

  Jeder Prüfpunkt wird unten in $script:Pruefungen eingetragen, zum Beispiel:

    @{ Id = 'A4'; Name = 'Raumflächen'; Phasen = @('entwurf', 'werk'); Run = { param($items) ... } }

  "Phasen" legt fest, für welche Planungsphase der Punkt gilt (die Nutzerin wählt sie vor dem Hochladen):
    'entwurf' = Checkliste Entwurfsplanung (Grundrisse 1:100)
    'werk'    = Checkliste Werkplanung (Grundrisse 1:50)
  "Run" bekommt die Textstücke des Plans (siehe pdf-text.ps1) und gibt pro Befund ein
  Ergebnis zurück, erzeugt mit New-Result. Ein leeres Ergebnis heißt: alles in Ordnung.
#>
. "$PSScriptRoot\pdf-text.ps1"

function New-Result($angabe, $ok, $wert, $detail) {
    [pscustomobject]@{ Angabe = $angabe; Ok = $ok; Wert = $wert; Detail = $detail }
}

# Aktive Prüfpunkte. Hier tragen wir sie nacheinander ein (Reihenfolge laut PRUEFKATALOG.md).
$script:Pruefungen = @()

function Get-AktivePruefungen([string]$Phase = 'entwurf') {
    @($script:Pruefungen | Where-Object { $_.Phasen -contains $Phase } | ForEach-Object { "$($_.Id) $($_.Name)" })
}

function Invoke-Pruefungen([string]$Path, [string]$Phase = 'entwurf') {
    $items = @(Get-PdfTextItems $Path)
    if ($items.Count -eq 0) {
        return @(New-Result 'PDF' $false '' 'Kein Text im PDF gefunden (gescannt oder Schrift in Linien umgewandelt).')
    }
    foreach ($p in ($script:Pruefungen | Where-Object { $_.Phasen -contains $Phase })) {
        & $p.Run $items
    }
}

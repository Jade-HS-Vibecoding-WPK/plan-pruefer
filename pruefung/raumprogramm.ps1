<#
  Add-on Raumprogramm (Experiment, 18.11.): Räume mit Flächen und Geschoss aus einem Grundriss lesen.

  Die Seite (raumprogramm.js) liest das Raumprogramm selbst (mit pdf.js, das kann auch Word- und iPhone-PDFs)
  und schickt nur die Grundrisse an den Server. Hier werden die Raumstempel gelesen (wie bei A3/A4: Name und Fläche)
  und jedem Raum ein Geschoss zugeordnet.

  Geschosse: Beschriftungen wie "Erdgeschoss", "Obergeschoss", "1. OG" im Plan. Stehen zwei verschiedene auf einem
  Blatt (zwei Grundrisse auf einer PDF), gehört jeder Raum zu der Beschriftung seines Grundrisses:
    - Beschriftungen nebeneinander (etwa gleiche Höhe): die nächste Beschriftung links vom Raum (oder die nächste)
    - Beschriftungen untereinander: die nächste Beschriftung unter dem Raum (oder die nächste)
  Gleiche Namen (zum Beispiel "Erdgeschoss" in der Bezeichnung und im Plankopf) zählen als ein Geschoss.

  Ohne diese Datei läuft der Planprüfer unverändert weiter (der Server lädt sie nur, wenn sie da ist).
#>

$script:RpGeschossMuster = '^(?i)(erd|ober|unter|keller|dach|staffel|sockel)geschoss\w*$|^(?i)(galerie|empore)$|^(EG|OG|UG|DG|KG|[1-9]\.\s*OG)$'

function Get-RpGeschossName([string]$t) {
    $x = $t.Trim()
    if ($x -match '^(?i)erd') { return 'Erdgeschoss' }
    if ($x -match '^(?i)ober' -or $x -cmatch '^OG$') { return 'Obergeschoss' }
    if ($x -cmatch '^([1-9])\.\s*OG$') { return "$($Matches[1]). Obergeschoss" }
    if ($x -match '^(?i)(unter|keller|sockel)' -or $x -cmatch '^(UG|KG)$') { return 'Untergeschoss' }
    if ($x -match '^(?i)(dach|staffel)' -or $x -cmatch '^DG$') { return 'Dachgeschoss' }
    if ($x -match '^(?i)(galerie|empore)') { return 'Galerie' }
    if ($x -cmatch '^EG$') { return 'Erdgeschoss' }
    $x
}

function Get-RaumprogrammRaeume($items) {
    $items = @($items)
    # "1." vor "Obergeschoss" gehört dazu
    $labels = New-Object System.Collections.Generic.List[object]
    foreach ($i in $items) {
        $text = $i.T
        # Auseinander geschrieben: "OBER" "GESCHOSS" (mit Sperrschrift), dann das Wort davor dazunehmen
        if ($text -match '^(?i)geschoss$') {
            $vorwort = $items | Where-Object { [math]::Abs($_.Y - $i.Y) -le 2 -and $_.X -lt $i.X -and ($i.X - $_.X) -le 120 -and $_.T -match '^(?i)(erd|ober|unter|keller|dach|staffel|sockel)$' } | Sort-Object { $i.X - $_.X } | Select-Object -First 1
            if (-not $vorwort) { continue }
            $text = $vorwort.T + 'geschoss'
        }
        if ($text -notmatch $script:RpGeschossMuster) { continue }
        $name = Get-RpGeschossName $text
        if ($name -eq 'Obergeschoss') {
            $vor = $items | Where-Object { [math]::Abs($_.Y - $i.Y) -le 2 -and $_.X -lt $i.X -and ($i.X - $_.X) -le 30 -and $_.T -match '^[1-9]\.$' } | Select-Object -First 1
            if ($vor) { $name = "$($vor.T -replace '\.$', ''). Obergeschoss" }
        }
        $labels.Add([pscustomobject]@{ Name = $name; X = $i.X; Y = $i.Y })
    }
    # Als einfaches Feld weiterrechnen: eine leere generische Liste führt in PowerShell 5.1 zu "Argumenttypen stimmen nicht überein"
    $labels = [object[]]$labels.ToArray()
    $namen = @($labels | ForEach-Object { $_.Name } | Select-Object -Unique)

    # Beschriftung mit Maßstab in derselben Zeile (Planbezeichnung) hat Vorrang vor Plankopf und Fließtext
    $mitMassstab = @($labels | Where-Object { $l = $_; @($items | Where-Object { [math]::Abs($_.Y - $l.Y) -le 3 -and $_.X -gt $l.X -and ($_.X - $l.X) -le 450 -and $_.T -match '^(M\s*)?1\s*:\s*\d{1,4}$' }).Count -gt 0 })
    $anker = if ($mitMassstab.Count -ge 1) { $mitMassstab } else { @($labels) }
    $nebeneinander = $false
    if ($anker.Count -ge 2) {
        $xs = @($anker | ForEach-Object { $_.X }); $ys = @($anker | ForEach-Object { $_.Y })
        $nebeneinander = (($xs | Measure-Object -Maximum).Maximum - ($xs | Measure-Object -Minimum).Minimum) -gt (($ys | Measure-Object -Maximum).Maximum - ($ys | Measure-Object -Minimum).Minimum)
    }
    $verschiedene = @($anker | ForEach-Object { $_.Name } | Select-Object -Unique).Count

    # Nur Flächen mit Komma (zum Beispiel 8,25): ganze Zahlen neben einem Namen sind meist Maßzahlen
    $raeume = foreach ($s in @(Get-Raumstempel $items | Where-Object { $_.Zahl -gt 0 -and $_.Wert -match '[.,]' })) {
        $geschoss = $null
        if ($verschiedene -ge 2) {
            $kand = if ($nebeneinander) { @($anker | Where-Object { $_.X -le $s.X + 20 } | Sort-Object { $s.X - $_.X }) } else { @($anker | Where-Object { $_.Y -ge $s.Y - 20 } | Sort-Object { $_.Y - $s.Y }) }
            if ($kand.Count -eq 0) { $kand = @($anker | Sort-Object { [math]::Abs($_.X - $s.X) + [math]::Abs($_.Y - $s.Y) }) }
            $geschoss = $kand[0].Name
        } elseif ($verschiedene -eq 1) { $geschoss = $anker[0].Name }
        [pscustomobject]@{ name = $(if ($s.NameText) { $s.NameText } else { '' }); flaeche = $s.Zahl; text = $s.Wert; geschoss = $geschoss; x = $s.X; y = $s.Y }
    }
    [pscustomobject]@{ geschosse = @($anker | ForEach-Object { $_.Name } | Select-Object -Unique); alleGeschossNamen = $namen; raeume = @($raeume) }
}

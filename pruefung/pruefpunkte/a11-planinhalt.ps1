<#
  A11 Planinhalt beschriftet (nur Werkplanung, Checkliste Werk G.3.6)

  Unter der Zeichnung steht die Bezeichnung des Plans, zum Beispiel
      GRUNDRISS ERDGESCHOSS  M 1:50
  Im Plankopf steht unter "Maßstab" noch einmal der Maßstab.

  Geprüft wird:
    1. Die Bezeichnung "GRUNDRISS ..." (oder nur der Geschossname, zum Beispiel "Erdgeschoss") mit Maßstab (1:zahl oder M1:zahl) in derselben Zeile ist vorhanden.
    2. Der Maßstab der Bezeichnung ist 1:50 (Werkplanung).
    3. Der Maßstab im Plankopf (unter "Maßstab") ist derselbe wie in der Bezeichnung.
       Findet sich im Plankopf kein Maßstab, wird dieser Vergleich übersprungen (kein Befund).
#>

function Get-A11Planinhalt($items) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    # Maßstab auch zusammengeschrieben mit M, zum Beispiel "M1:50"
    $massstab = '^(M\s*)?1\s*:\s*\d{1,4}$'

    # 1. Bezeichnung mit Maßstab in einer Zeile
    $titel = $null; $skala = $null
    foreach ($g in @($items | Where-Object { $_.T -match '^(?i)(grundriss\w*|(erd|ober|unter|keller|dach|staffel)geschoss\w*)$' })) {
        $s = $items | Where-Object { $_ -ne $g -and [math]::Abs($_.Y - $g.Y) -le 3 -and $_.X -gt $g.X -and ($_.X - $g.X) -le 450 -and $_.T -match $massstab } | Sort-Object X | Select-Object -First 1
        if ($s) { $titel = $g; $skala = $s; break }
    }
    if (-not $titel) {
        $ergebnisse.Add((New-Result 'Planbezeichnung' $false '' 'Unter der Zeichnung fehlt die Bezeichnung mit Maßstab, zum Beispiel "GRUNDRISS ERDGESCHOSS M 1:50".'))
        return $ergebnisse
    }
    $skalaText = ($skala.T -replace '\s', '' -replace '^M', '')
    $ergebnisse.Add((New-Result 'Planbezeichnung' $true "Grundriss, M $skalaText" '' $titel.X $titel.Y))

    # 2. Werkplanung = 1:50
    if ($skalaText -ne '1:50') {
        $ergebnisse.Add((New-Result 'Maßstab' $false "M $skalaText" "Der Maßstab der Planbezeichnung ist $skalaText, in der Werkplanung wird 1:50 erwartet." $skala.X $skala.Y))
    }

    # 3. Vergleich mit dem Plankopf (Maßstab-Feld, darunter die Zahl)
    $label = $items | Where-Object { $_.T -match '^Ma(ß|ss)stab:?$' } | Select-Object -First 1
    if ($label) {
        $kopf = $items | Where-Object { $_ -ne $skala -and [math]::Abs($_.X - $label.X) -le 15 -and ($_.Y - $label.Y) -ge 5 -and ($_.Y - $label.Y) -le 40 -and $_.T -match $massstab } | Sort-Object Y | Select-Object -First 1
        if ($kopf) {
            $kopfText = ($kopf.T -replace '\s', '' -replace '^M', '')
            if ($kopfText -ne $skalaText) {
                $ergebnisse.Add((New-Result 'Maßstab im Plankopf' $false "Kopf $kopfText, Plan $skalaText" "Der Maßstab im Plankopf ($kopfText) passt nicht zur Planbezeichnung ($skalaText)." $kopf.X $kopf.Y))
            } else {
                $ergebnisse.Add((New-Result 'Maßstab im Plankopf' $true $kopfText '' $kopf.X $kopf.Y))
            }
        }
    }
    $ergebnisse | Sort-Object { $_.Ok }
}

$script:Pruefungen += @{
    Id     = 'A11'
    Name   = 'Planinhalt beschriftet'
    Phasen = @('werk')
    Run    = { param($items) Get-A11Planinhalt $items }
}
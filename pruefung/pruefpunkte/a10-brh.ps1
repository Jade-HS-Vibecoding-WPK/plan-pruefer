<#
  A10 BRH (Brüstungshöhe) je Fenster, nur Werkplanung.

  Im Werkplan steht an jedem Fenster "BRH" mit einem Wert dahinter, zum Beispiel
      BRH 95        (Brüstungshöhe 95 cm)
      BRH 0,00      (bodentiefes Fenster)

  Geprüft wird:
    1. Es gibt mindestens eine BRH-Angabe im Plan.
    2. Jede BRH-Angabe hat hinter sich auf derselben Zeile einen Wert (eine Zahl).
       Fehlt der Wert, wird die Stelle mit Position gemeldet.

  Noch nicht geprüft: ob an jedem Fenster eine BRH steht (dafür müsste die Fensterzahl aus der
  Zeichnung bekannt sein, später mit der Bemaßung A2).
#>

$script:BrhWert = '^[+±-]?\d{1,3}([.,]\d{1,2})?$'

function Get-A10Brh($items) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $brh = @($items | Where-Object { $_.T -cmatch '^BRH\b' } | Sort-Object Y, X)

    if ($brh.Count -eq 0) {
        $ergebnisse.Add((New-Result 'BRH' $false '' 'Im Plan steht keine BRH-Angabe (Brüstungshöhe, zum Beispiel "BRH 95") an den Fenstern.'))
        return $ergebnisse
    }

    $nr = 0
    foreach ($b in $brh) {
        $nr++
        $wert = $null
        $einStueck = $b.T -cmatch '^BRH\s*:?\s*(?<w>\S+)$'
        $w = $Matches['w']
        if ($einStueck -and $w -match $script:BrhWert) { $wert = $w }
        else {
            # normal: der Wert steht rechts daneben auf derselben Zeile
            $n = $items | Where-Object {
                $_ -ne $b -and [math]::Abs($_.Y - $b.Y) -le 2.5 -and $_.X -gt ($b.X + 3) -and ($_.X - $b.X) -le 45 -and $_.T -match $script:BrhWert
            } | Sort-Object X | Select-Object -First 1
            # Text, der im Plan hochkant (um 90 Grad gedreht) steht: der Wert steht direkt darüber
            if (-not $n) {
                $n = $items | Where-Object {
                    $_ -ne $b -and [math]::Abs($_.X - $b.X) -le 2 -and ($b.Y - $_.Y) -ge 15 -and ($b.Y - $_.Y) -le 26 -and $_.T -match $script:BrhWert
                } | Select-Object -First 1
            }
            if ($n) { $wert = $n.T }
        }        if ($wert) { $ergebnisse.Add((New-Result "BRH $nr" $true $wert '' $b.X $b.Y)) }
        else { $ergebnisse.Add((New-Result "BRH $nr" $false '' "Die BRH-Angabe an dieser Stelle hat keinen Wert (zum Beispiel 'BRH 95')." $b.X $b.Y)) }
    }
    $ergebnisse | Sort-Object { $_.Ok }
}

$script:Pruefungen += @{
    Id     = 'A10'
    Name   = 'BRH je Fenster'
    Phasen = @('werk')
    Run    = { param($items) Get-A10Brh $items }
}

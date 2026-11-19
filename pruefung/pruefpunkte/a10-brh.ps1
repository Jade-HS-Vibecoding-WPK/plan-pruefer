<#
  A10 BRH (Brüstungshöhe) je Fenster, nur Werkplanung.

  Im Werkplan steht an jedem Fenster "BRH" mit einem Wert dahinter, zum Beispiel
      BRH 95        (Brüstungshöhe 95 cm)
      BRH 0,00      (bodentiefes Fenster)

  Geprüft wird:
    1. Es gibt mindestens eine BRH-Angabe im Plan.
    2. Jede BRH-Angabe hat hinter sich auf derselben Zeile einen Wert (eine Zahl).
       Fehlt der Wert, wird die Stelle mit Position gemeldet.

    3. (seit 19.11.) An JEDEM Fenster steht eine BRH. Ohne KI, nur aus dem Plantext:
       - Fenster = Öffnungsmaß "Breite über Höhe" (zum Beispiel 2,51 / 1,30) im Gebäude, mit einer Höhe unter 2,00 m.
         Waagrechter Text: Breite genau über der Höhe. Hochkant (linke und rechte Wand): Breite genau links daneben.
         Nur an der Außenwand (höchstens 75 Punkt von der Gebäudekante): Innentüren und Durchgänge zählen nicht.
         Türen (Höhe 2,01, 2,31 ...) und bodentiefe Fenster/Fenstertüren (ab 2,00 m) lassen sich so nicht von Türen
         unterscheiden und werden hier nicht geprüft.
       - Gebäude = Achsraster (wie bei A2). Ohne Achsen: Bereich der Raumstempel. Die Öffnungsmaßketten außen zählen nicht.
       - Jedes Fenster bekommt die nächste BRH auf seiner Wandseite (außen, höchstens 30 Punkt seitlich versetzt,
         jede BRH nur einmal). Fehlt sie, kommt ein Befund mit der Lage des Fensters.
       Ein Versuch mit der KI (19.11.) hat das fehlende BRH übersehen und war zu langsam, darum ohne KI.
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

# Fenster im Plantext: Öffnungsmaß "Breite / Höhe" mit Höhe unter 2,00 m, im Gebäude. Liefert Lage, Seite, Breite, Höhe.
function Get-A10Fenster($items, $box) {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $zahl = { param($t) $v = 0.0; [void][double]::TryParse(($t -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$v); $v }
    $breiteMuster = '^(\d,\d\d|\d{2,3})$'
    $kand = New-Object System.Collections.Generic.List[object]
    foreach ($h in @($items | Where-Object { $_.T -match '^\d,\d\d$' })) {
        $hw = & $zahl $h.T
        if ($hw -lt 0.3 -or $hw -ge 2.0) { continue }
        if ($h.X -lt $box.Links -or $h.X -gt $box.Rechts -or $h.Y -lt $box.Oben -or $h.Y -gt $box.Unten) { continue }
        # Breite genau darüber (waagrechter Text) oder genau daneben (hochkant gedrehter Text)
        $b = $items | Where-Object { $_ -ne $h -and $_.T -match $breiteMuster -and [math]::Abs($_.X - $h.X) -le 3 -and ($h.Y - $_.Y) -ge 5 -and ($h.Y - $_.Y) -le 16 } | Select-Object -First 1
        # hochkant: die Breite steht links neben der Höhe (so liest ArchiCAD gedrehten Text; "1,13⁵ / 2,13⁵" ist eine Tür)
        if (-not $b) { $b = $items | Where-Object { $_ -ne $h -and $_.T -match $breiteMuster -and [math]::Abs($_.Y - $h.Y) -le 3 -and ($h.X - $_.X) -ge 5 -and ($h.X - $_.X) -le 16 } | Select-Object -First 1 }
        if (-not $b) { continue }
        $bw = if ($b.T -match ',') { & $zahl $b.T } else { (& $zahl $b.T) / 100 }
        if ($bw -lt 0.3) { continue }
        # Seite: die nächste Außenkante des Gebäudes
        $abst = @{ oben = $h.Y - $box.Oben; unten = $box.Unten - $h.Y; links = $h.X - $box.Links; rechts = $box.Rechts - $h.X }
        $seite = ($abst.GetEnumerator() | Sort-Object Value | Select-Object -First 1).Key
        # Fenster mit BRH sitzen an der Außenwand. Maße weiter innen gehören zu Innentüren und Durchgängen.
        if ($abst[$seite] -gt 75) { continue }
        $kand.Add([pscustomobject]@{ X = $h.X; Y = $h.Y; Hoehe = $h.T; Breite = $b.T; Seite = $seite; HoeheItem = $h; BreiteItem = $b })
    }
    # Ein "Fenster", dessen Breite selbst die Höhe eines anderen Fensters ist, ist nur ein Maß darunter
    $hoehenItems = @($kand | ForEach-Object { $_.HoeheItem })
    @($kand | Where-Object { $hoehenItems -notcontains $_.BreiteItem })
}

# Gebäudebereich: Achsraster (wie A2), sonst Bereich der Raumstempel, jeweils mit etwas Rand
function Get-A10Gebaeude($items, $linien) {
    $kern = $null
    if (@($linien).Count -gt 0 -and (Get-Command Get-A2Kern -ErrorAction SilentlyContinue)) { $kern = Get-A2Kern $items $linien }
    if ($kern) { return [pscustomobject]@{ Links = $kern.Links - 15; Rechts = $kern.Rechts + 15; Oben = $kern.Oben - 15; Unten = $kern.Unten + 15; Quelle = 'Achsraster' } }
    $st = @(Get-Raumstempel $items)
    if ($st.Count -lt 2) { return $null }
    [pscustomobject]@{ Links = ($st | Measure-Object X -Minimum).Minimum - 70; Rechts = ($st | Measure-Object X -Maximum).Maximum + 70
        Oben = ($st | Measure-Object Y -Minimum).Minimum - 70; Unten = ($st | Measure-Object Y -Maximum).Maximum + 70; Quelle = 'Raumstempel' }
}

# Jedes Fenster braucht eine BRH auf seiner Wandseite (außen)
function Get-A10FensterOhneBrh($items, $linien) {
    $brh = @($items | Where-Object { $_.T -cmatch '^BRH\b' })
    if ($brh.Count -eq 0) { return @() }   # "keine BRH im Plan" meldet schon Get-A10Brh
    $box = Get-A10Gebaeude $items $linien
    if (-not $box) { return @(New-Result 'BRH an jedem Fenster' $true 'nicht prüfbar: Gebäude nicht erkennbar (kein Achsraster, keine Raumstempel)' '') }
    $fenster = @(Get-A10Fenster $items $box)
    if ($fenster.Count -eq 0) { return @(New-Result 'BRH an jedem Fenster' $true 'nicht prüfbar: keine Fenstermaße (Breite / Höhe) nah an den Außenwänden gefunden' '') }
    $frei = New-Object System.Collections.Generic.List[object]; foreach ($b in $brh) { $frei.Add($b) }
    $ohne = New-Object System.Collections.Generic.List[object]
    # Jedes Fenster nimmt die nächste noch freie BRH auf seiner Seite (Fenster liegen weiter auseinander als 30 Punkt)
    foreach ($f in $fenster) {
        $passend = @($frei | Where-Object {
                $b = $_
                switch ($f.Seite) {
                    'oben' { $b.Y -lt $f.Y -and ($f.Y - $b.Y) -le 120 -and [math]::Abs($b.X - $f.X) -le 30 }
                    'unten' { $b.Y -gt $f.Y -and ($b.Y - $f.Y) -le 120 -and [math]::Abs($b.X - $f.X) -le 30 }
                    'links' { $b.X -lt $f.X -and ($f.X - $b.X) -le 120 -and [math]::Abs($b.Y - $f.Y) -le 30 }
                    'rechts' { $b.X -gt $f.X -and ($b.X - $f.X) -le 120 -and [math]::Abs($b.Y - $f.Y) -le 30 }
                }
            } | Sort-Object { [math]::Abs($_.X - $f.X) + [math]::Abs($_.Y - $f.Y) })
        if ($passend.Count -gt 0) { [void]$frei.Remove($passend[0]) } else { $ohne.Add($f) }
    }
    $erg = New-Object System.Collections.Generic.List[object]
    foreach ($f in $ohne) {
        $erg.Add((New-Result "BRH am Fenster ($($f.Seite))" $false "$($f.Breite) / $($f.Hoehe)" "Am Fenster an der Wand $($f.Seite) (Öffnung $($f.Breite) / $($f.Hoehe)) steht keine BRH-Angabe. Jedes Fenster braucht außen eine Brüstungshöhe, zum Beispiel 'BRH 95'." $f.X $f.Y))
    }
    if ($ohne.Count -eq 0) { $erg.Add((New-Result 'BRH an jedem Fenster' $true "$($fenster.Count) von $($fenster.Count) Fenstern (Höhe unter 2 m) haben eine BRH" '' $fenster[0].X $fenster[0].Y)) }
    $erg
}

$script:Pruefungen += @{
    Id     = 'A10'
    Name   = 'BRH je Fenster'
    Phasen = @('werk')
    Run    = { param($items, $pdfPfad) $l = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $l = @(Get-PdfLinienCached $pdfPfad) }; @(Get-A10Brh $items) + @(Get-A10FensterOhneBrh $items $l) }
}

<#
  A2 Bemaßung (nur Werkplanung, Grundriss 1:50)

  Grundlage ist die Vorgabe vom Team (DIN 1356-1 und DIN 406):
    - Maße ab 1,00 m stehen in Metern mit zwei Nachkommastellen (3,65), Maße unter 1,00 m in Zentimetern
      ohne Komma (24 oder 88). Halbe Zentimeter stehen hochgestellt (1,25 mit kleiner 5 daneben = 1,255 m).
    - Um das Gebäude laufen Maßketten: Öffnungsmaße (Wandstücke, Fenster, Türen), Achse zu Bauteil, Achse zu Achse
      (nur wenn es Achsen gibt) und das Gesamtmaß (Außenkante des Gebäudes). Vorsprungsmaße sind freiwillig.
      Die Höhe der Öffnungen (die Zahl darunter) wird im Grundriss nicht geprüft.

  Geprüft wird pro Seite (oben, unten, links, rechts), außerhalb des Achsrasters:
    1. Es gibt eine Maßkette (mindestens zwei Maßzahlen auf einer Linie).
    2. Es gibt ein Gesamtmaß (eine Zeile mit genau einer Maßzahl).
    3. Das Gesamtmaß ist gleich der Summe einer Maßkette der Seite (der Öffnungsmaßkette), Toleranz 5 mm.
    4. Gibt es in der Richtung Achsen (aus A9), passt eine Maßkette zu den Achsabständen ("Achse zu Achse").
       Der Abstand der Achsen wird aus den Linien im PDF berechnet (Punkt mal Maßstab).
    5. Schreibweise: Maße unter 1 m ohne Komma in cm (nicht 0,88), halbe Zentimeter hochgestellt (nicht 1,255).
  Noch nicht geprüft: Achse zu Bauteil, Innenmaße der Wände, Doppelbemaßung, Öffnungshöhen.
#>

$script:MasszahlMuster = '^\d{1,3}[.,]\d{2,3}$'
$script:A2Zeichenbreite = 4.25
$script:A2Toleranz = 0.011        # Achsabstände aus den Linien (ArchiCAD rundet auf 1 cm)
$script:A2ToleranzSumme = 0.006   # Summen von Maßzahlen (5 mm genau, ein Fehler von 1 cm soll auffallen)

# Nur die Achsen, die zum Raster gehören (eine Richtung). Weg fallen:
#  - Strichlinien, die viel kürzer sind als die übrigen (unter 60 % der mittleren Länge, zum Beispiel verdeckte Kanten)
#  - Strichlinien am Rand, die weit abseits liegen (Abstand zur Nachbarachse über 4 mal dem mittleren Achsabstand),
#    zum Beispiel gestrichelte Linien bei den Maßketten (so im Museumsplan vom 18.11.)
function Get-A2EchteAchsen($achsen) {
    $a = @($achsen | Sort-Object Lage)
    if ($a.Count -lt 3) { return $a }
    $laengen = @($a | ForEach-Object { $_.Bis - $_.Von } | Sort-Object)
    $mittelL = $laengen[[int][math]::Floor($laengen.Count / 2)]
    $a = @($a | Where-Object { ($_.Bis - $_.Von) -ge 0.6 * $mittelL })
    while ($a.Count -ge 3) {
        $abst = @(for ($i = 1; $i -lt $a.Count; $i++) { $a[$i].Lage - $a[$i - 1].Lage }) | Sort-Object
        $mittelA = $abst[[int][math]::Floor($abst.Count / 2)]
        if (($a[1].Lage - $a[0].Lage) -gt 4 * $mittelA) { $a = @($a | Select-Object -Skip 1); continue }
        if (($a[$a.Count - 1].Lage - $a[$a.Count - 2].Lage) -gt 4 * $mittelA) { $a = @($a | Select-Object -First ($a.Count - 1)); continue }
        break
    }
    $a
}

function Get-A2Kern($items, $linien) {
    $ach = @(Get-AchsenLinien @($linien))
    $senk = @(Get-A2EchteAchsen @($ach | Where-Object { $_.Richtung -eq 'senkrecht' })); $waag = @(Get-A2EchteAchsen @($ach | Where-Object { $_.Richtung -eq 'waagrecht' }))
    if ($senk.Count -ge 2 -and $waag.Count -ge 2) {
        return [pscustomobject]@{
            Links = ($senk | Measure-Object Lage -Minimum).Minimum; Rechts = ($senk | Measure-Object Lage -Maximum).Maximum
            Oben = ($waag | Measure-Object Lage -Minimum).Minimum;  Unten = ($waag | Measure-Object Lage -Maximum).Maximum
            Quelle = 'Achsraster'; SenkLagen = @($senk | ForEach-Object { $_.Lage } | Sort-Object); WaagLagen = @($waag | ForEach-Object { $_.Lage } | Sort-Object)
        }
    }
    # Ohne Achsraster ist die Außenkante des Gebäudes im Text nicht zu finden: die Maßketten werden dann nicht geprüft
    $null
}

# Maßstab aus dem Plan (zum Beispiel "1:50" -> 50). Ohne Angabe 50.
function Get-A2Massstab($items) {
    $m = $items | Where-Object { $_.T -match '^1\s*:\s*(20|25|50|75|100)$' } | Select-Object -First 1
    if ($m) { [double](($m.T -replace '^1\s*:\s*', '')) } else { 50.0 }
}

# Gehört das Textstück zur Seite? Das Gebäude (Kern) ist durch das Raster begrenzt.
function Test-A2Seite($i, $kern, [string]$seite) {
    $rand = 8
    switch ($seite) {
        'oben'   { return ($i.Y -lt ($kern.Oben - $rand) -and $i.X -gt ($kern.Links - 60) -and $i.X -lt ($kern.Rechts + 60)) }
        'unten'  { return ($i.Y -gt ($kern.Unten + $rand) -and $i.X -gt ($kern.Links - 60) -and $i.X -lt ($kern.Rechts + 60)) }
        'links'  { return ($i.X -lt ($kern.Links - $rand) -and $i.Y -gt ($kern.Oben - 60) -and $i.Y -lt ($kern.Unten + 60)) }
        default  { return ($i.X -gt ($kern.Rechts + $rand) -and $i.Y -gt ($kern.Oben - 60) -and $i.Y -lt ($kern.Unten + 60)) }
    }
}

# Maßzahlen einer Seite mit Wert in Metern. Hochgestellte 5 (halber Zentimeter) wird zur Zahl davor gezählt.
# Meter: 1,53 oder 1,25 plus Hochzahl. Zentimeter: 78 oder 13 plus Hochzahl.
function Get-A2Zahlen($items, $kern, [string]$seite) {
    $waagrecht = ($seite -eq 'oben' -or $seite -eq 'unten')
    # BRH-Werte (Brüstungshöhe, A10) sind keine Maßketten-Zahlen
    $brh = @($items | Where-Object { $_.T -cmatch '^BRH' })
    $istBrhWert = {
        param($n)
        foreach ($b in $brh) {
            if ([math]::Abs($n.Y - $b.Y) -le 2.5 -and ($n.X - $b.X) -gt 3 -and ($n.X - $b.X) -le 45) { return $true }
            if ([math]::Abs($n.X - $b.X) -le 2 -and ($b.Y - $n.Y) -ge 15 -and ($b.Y - $n.Y) -le 26) { return $true }
        }
        $false
    }
    # Zahlen mit Einheit "m" oder "m²" rechts daneben sind Flächen oder Umfänge aus Raumstempeln (zum Beispiel eine Terrasse
    # außerhalb des Gebäudes mit 39,59 m²), keine Maßzahlen: Maßketten schreiben keine Einheit
    $einheiten = @($items | Where-Object { $_.T -match '^m(\s*[²2])?$' })
    $mitEinheit = {
        param($n)
        foreach ($e in $einheiten) { if ([math]::Abs($e.Y - $n.Y) -le 2.5 -and $e.X -gt $n.X -and ($e.X - $n.X) -le 40) { return $true } }
        $false
    }
    $band = @($items | Where-Object { ($_.T -match $script:MasszahlMuster -or $_.T -match '^\d{1,2}$') -and (Test-A2Seite $_ $kern $seite) -and -not (& $istBrhWert $_) -and -not (& $mitEinheit $_) })
    $quer = { param($i) if ($waagrecht) { $i.Y } else { $i.X } }
    $laengs = { param($i) if ($waagrecht) { $i.X } else { $i.Y } }
    $verbraucht = New-Object System.Collections.Generic.HashSet[object]
    $hoch = @{}
    foreach ($s in @($band | Where-Object { $_.T -match '^\d$' })) {
        $beste = $null
        foreach ($n in $band) {
            if ($n -eq $s -or $n.T.Length -lt 2) { continue }
            $dq = (& $quer $s) - (& $quer $n)
            $erwartet = (& $laengs $n) + $(if ($waagrecht) { 1 } else { -1 }) * $n.T.Length * $script:A2Zeichenbreite
            $dl = [math]::Abs((& $laengs $s) - $erwartet)
            if ($dq -ge -4.5 -and $dq -le -1.5 -and $dl -le 4.5 -and ($null -eq $beste -or $dl -lt $beste.Abstand)) { $beste = [pscustomobject]@{ N = $n; Abstand = $dl } }
        }
        if ($beste) { [void]$verbraucht.Add($s); $hoch[$beste.N] = [int]$s.T }
    }
    foreach ($n in $band) {
        if ($verbraucht.Contains($n)) { continue }
        $wert = 0.0; $art = 'cm'
        if ($n.T -match $script:MasszahlMuster) { $wert = [double]::Parse(($n.T -replace ',', '.'), [System.Globalization.CultureInfo]::InvariantCulture); $art = 'm' }
        else { $wert = [double]$n.T / 100 }
        if ($hoch.ContainsKey($n)) { $wert += $hoch[$n] * 0.001 }
        [pscustomobject]@{ Item = $n; Wert = $wert; Art = $art; Quer = (& $quer $n); Laengs = (& $laengs $n); Hochzahl = $hoch.ContainsKey($n); Text = $n.T }
    }
}

# Zeilen: Maßzahlen auf einer Linie (gleiche Querposition, 2 Punkt Toleranz).
function Get-A2Zeilen($zahlen) {
    $zeilen = @(); $akt = @(); $ende = $null
    foreach ($z in @($zahlen | Sort-Object Quer)) {
        if ($akt.Count -gt 0 -and ($z.Quer - $akt[0].Quer) -gt 2) { $zeilen += , $akt; $akt = @() }
        $akt += $z
    }
    if ($akt.Count -gt 0) { $zeilen += , $akt }
    foreach ($z in $zeilen) {
        [pscustomobject]@{ Quer = ($z | Measure-Object Quer -Average).Average; Zahlen = @($z); Anzahl = @($z).Count; Summe = ($z | Measure-Object Wert -Sum).Sum }
    }
}

function Format-Meter([double]$w) { $w.ToString('0.00', (New-Object System.Globalization.CultureInfo('de-DE'))) }

function Get-A2Massketten($items, $linien) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $kern = Get-A2Kern $items $linien
    if (-not $kern) {
        $ergebnisse.Add((New-Result 'Maßketten' $true 'nicht geprüft' 'Ohne Achsraster lässt sich das Gebäude nicht abgrenzen, die Maßketten wurden nicht geprüft.'))
        return $ergebnisse
    }
    $massstab = Get-A2Massstab $items
    $ptZuM = 0.352778 / 1000 * $massstab

    foreach ($seite in 'oben', 'unten', 'links', 'rechts') {
        $waagrecht = ($seite -eq 'oben' -or $seite -eq 'unten')
        $zahlen = @(Get-A2Zahlen $items $kern $seite)
        $zeilen = @(Get-A2Zeilen $zahlen)
        $x0 = switch ($seite) { 'oben' { ($kern.Links + $kern.Rechts) / 2 } 'unten' { ($kern.Links + $kern.Rechts) / 2 } 'links' { $kern.Links - 40 } default { $kern.Rechts + 40 } }
        $y0 = switch ($seite) { 'oben' { $kern.Oben - 40 } 'unten' { $kern.Unten + 40 } default { ($kern.Oben + $kern.Unten) / 2 } }
        $befunde = 0
        $notizen = @()

        # 1. Maßkette vorhanden
        $ketten = @($zeilen | Where-Object { $_.Anzahl -ge 2 })
        if ($ketten.Count -eq 0) {
            $ergebnisse.Add((New-Result "Maßkette $seite" $false '' "Auf der Seite '$seite' des Gebäudes ist keine Maßkette zu finden (Maßzahlen wie 1,53 in einer Reihe)." $x0 $y0))
            continue
        }

        # 5. Schreibweise
        foreach ($z in $zahlen) {
            if ($z.Art -eq 'm' -and $z.Text -match '^0[.,]') {
                $ergebnisse.Add((New-Result "Maßkette $seite" $false $z.Text "Schreibweise: Maße unter 1,00 m stehen in Zentimetern ohne Komma (statt $($z.Text) zum Beispiel $([math]::Round($z.Wert * 100)))." $z.Item.X $z.Item.Y)); $befunde++
            } elseif ($z.Art -eq 'm' -and $z.Text -match '[.,]\d{3}$') {
                $ergebnisse.Add((New-Result "Maßkette $seite" $false $z.Text "Schreibweise: Halbe Zentimeter stehen hochgestellt (statt $($z.Text) zum Beispiel $($z.Text.Substring(0, $z.Text.Length - 1)) mit kleiner Hochzahl)." $z.Item.X $z.Item.Y)); $befunde++
            }
        }

        # 2. Gesamtmaß = einzelne Zahl in einer Zeile, die größte
        $einzeln = @($zeilen | Where-Object { $_.Anzahl -eq 1 -and $_.Zahlen[0].Art -eq 'm' } | Sort-Object { $_.Zahlen[0].Wert } -Descending)
        $gesamt = $null
        if ($einzeln.Count -gt 0) { $gesamt = $einzeln[0].Zahlen[0] }
        if (-not $gesamt) {
            $ergebnisse.Add((New-Result "Maßkette $seite" $false '' "Auf der Seite '$seite' fehlt das Gesamtmaß (eine einzelne Maßzahl für die Außenkante des Gebäudes)." $x0 $y0)); $befunde++
        } else {
            # 3. Gesamtmaß = Summe einer Maßkette
            $kandidaten = @($zeilen | Where-Object { $_.Anzahl -ge 3 })
            $passt = @($kandidaten | Where-Object { [math]::Abs($_.Summe - $gesamt.Wert) -le $script:A2ToleranzSumme })
            if ($passt.Count -gt 0) { $notizen += "Gesamtmaß $(Format-Meter $gesamt.Wert) = Summe der Öffnungsmaße" }
            elseif ($kandidaten.Count -eq 0) {
                $ergebnisse.Add((New-Result "Maßkette $seite" $false (Format-Meter $gesamt.Wert) "Auf der Seite '$seite' gibt es zum Gesamtmaß $(Format-Meter $gesamt.Wert) keine Maßkette mit Teilmaßen (Öffnungsmaße)." $gesamt.Item.X $gesamt.Item.Y)); $befunde++
            } else {
                $nah = $kandidaten | Sort-Object { [math]::Abs($_.Summe - $gesamt.Wert) } | Select-Object -First 1
                $diff = [math]::Abs($nah.Summe - $gesamt.Wert)
                # Plan mit hochgestellten Millimetern (Hochzahl nicht 5, zum Beispiel 25,68 mit kleiner 8): jede Zahl ist gerundet,
                # unter 1 cm Unterschied ist deshalb nur ein Hinweis (Unsicheres als Hinweis, Regel vom Team)
                $mm = @($nah.Zahlen + @($gesamt) | Where-Object { $_.Hochzahl -and ([math]::Round($_.Wert * 1000) % 5) -ne 0 }).Count -gt 0
                $r = New-Result "Maßkette $seite" $false (Format-Meter $gesamt.Wert) "Das Gesamtmaß $(Format-Meter $gesamt.Wert) auf der Seite '$seite' stimmt mit keiner Maßkette überein: die nächstliegende Kette ergibt $(Format-Meter $nah.Summe) (Unterschied $(Format-Meter $diff)). Eine Teilzahl ist falsch oder fehlt." $gesamt.Item.X $gesamt.Item.Y
                if ($mm -and $diff -lt 0.01) {
                    $r.Detail = "Hinweis: Das Gesamtmaß $($gesamt.Wert.ToString('0.000', (New-Object System.Globalization.CultureInfo('de-DE')))) m auf der Seite '$seite' weicht um $([math]::Round($diff * 1000)) mm von der Summe der Maßkette ab. Bei Millimeter-Angaben kann das an der Rundung liegen, bitte nachrechnen."
                    $r.Quelle = 'hinweis'
                }
                $ergebnisse.Add($r); $befunde++
            }
        }

        # 4. Achse zu Achse (nur wenn es Achsen in dieser Richtung gibt)
        $lagen = if ($waagrecht) { @($kern.SenkLagen) } else { @($kern.WaagLagen) }
        if ($lagen.Count -ge 2) {
            $abstaende = @(); for ($i = 1; $i -lt $lagen.Count; $i++) { $abstaende += ($lagen[$i] - $lagen[$i - 1]) * $ptZuM }
            $beste = $null
            foreach ($zeile in $ketten) {
                $frei = New-Object System.Collections.Generic.List[double]; foreach ($w in $zeile.Zahlen) { $frei.Add($w.Wert) }
                $treffer = 0
                foreach ($a in $abstaende) {
                    $idx = -1; for ($k = 0; $k -lt $frei.Count; $k++) { if ([math]::Abs($frei[$k] - $a) -le $script:A2Toleranz) { $idx = $k; break } }
                    if ($idx -ge 0) { $treffer++; $frei.RemoveAt($idx) }
                }
                if ($null -eq $beste -or $treffer -gt $beste.Treffer -or ($treffer -eq $beste.Treffer -and $zeile.Anzahl -lt $beste.Zeile.Anzahl)) { $beste = [pscustomobject]@{ Treffer = $treffer; Zeile = $zeile } }
            }
            $abstandText = ($abstaende | ForEach-Object { Format-Meter $_ }) -join '; '
            if ($beste.Treffer -eq $abstaende.Count) { $notizen += "Achse zu Achse stimmt ($abstandText)" }
            elseif ($beste.Treffer -ge 1) {
                $r = New-Result "Maßkette $seite" $false $abstandText "Achse zu Achse auf der Seite '$seite': Die Achsabstände im Plan sind $abstandText m, die passendste Maßkette stimmt aber nur bei $($beste.Treffer) von $($abstaende.Count) Abständen." $x0 $y0
                # Sehr feines Raster (Modulraster, mehr als 15 Abstände): fehlende oder zusätzliche Strichlinien sind nicht sicher zu
                # unterscheiden, deshalb nur ein Hinweis
                if ($abstaende.Count -gt 15) {
                    $r.Detail = "Hinweis: Achse zu Achse auf der Seite '$seite' (feines Raster mit $($abstaende.Count + 1) Linien): $($beste.Treffer) von $($abstaende.Count) Abständen passen zur Maßkette. Bitte prüfen, ob eine Rasterlinie fehlt oder eine Zahl falsch ist."
                    $r.Quelle = 'hinweis'
                }
                $ergebnisse.Add($r); $befunde++
            } else {
                $ergebnisse.Add((New-Result "Maßkette $seite" $false $abstandText "Auf der Seite '$seite' fehlt die Maßkette 'Achse zu Achse' (Achsabstände im Plan: $abstandText m)." $x0 $y0)); $befunde++
            }
        }

        if ($befunde -eq 0) { $ergebnisse.Add((New-Result "Maßkette $seite" $true ($notizen -join '; ') '' $ketten[0].Zahlen[0].Item.X $ketten[0].Zahlen[0].Item.Y)) }
    }
    $ergebnisse | Sort-Object { $_.Ok }
}

# Gesamtmaße des Gebäudes (Breite aus der Kette oben oder unten, Tiefe links oder rechts). Für A5 (Flächenplausibilität).
# Liefert $null, wenn kein Achsraster da ist, sonst Breite und Tiefe in Metern (0, wenn nicht gefunden).
function Get-A2Gesamtmasse($items, $linien) {
    $kern = Get-A2Kern $items $linien
    if (-not $kern) { return $null }
    $werte = @{}
    foreach ($seite in 'oben', 'unten', 'links', 'rechts') {
        $zeilen = @(Get-A2Zeilen @(Get-A2Zahlen $items $kern $seite))
        $einzeln = @($zeilen | Where-Object { $_.Anzahl -eq 1 -and $_.Zahlen[0].Art -eq 'm' } | Sort-Object { $_.Zahlen[0].Wert } -Descending)
        $werte[$seite] = if ($einzeln.Count -gt 0) { $einzeln[0].Zahlen[0].Wert } else { 0.0 }
    }
    $b = if ($werte['oben'] -gt 0) { $werte['oben'] } else { $werte['unten'] }
    $tt = if ($werte['links'] -gt 0) { $werte['links'] } else { $werte['rechts'] }
    [pscustomobject]@{ Breite = $b; Tiefe = $tt }
}
$script:Pruefungen += @{
    Id     = 'A2'
    Name   = 'Bemaßung'
    Phasen = @('werk')
    Run    = { param($items, $pdfPfad) $l = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $l = @(Get-PdfLinienCached $pdfPfad) }; Get-A2Massketten $items $l }
}
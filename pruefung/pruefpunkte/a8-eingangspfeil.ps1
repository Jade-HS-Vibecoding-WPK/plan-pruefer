<#
  A8 Eingangspfeil (Entwurf und Werkplanung)

  Der Eingangspfeil steht vor der Eingangstür und zeigt auf sie. Er kann sehr verschieden aussehen
  (siehe testplaene\Eingangspfeile.pdf): ein einfacher Pfeil aus Linien, ein Pfeil mit Dreieck, ein ausgefülltes
  oder nur umrandetes Dreieck, klein oder groß, in beliebiger Farbe.

  Gemeinsam ist allen Formen eine Spitze: zwei gleich lange, schräg stehende Striche, die sich in einem Punkt treffen
  und deren Winkelhalbierende waagrecht oder senkrecht liegt (Pfeilspitze oder Dreieck, Öffnungswinkel 40 bis 130 Grad).
  Die Striche und Türbögen liest Get-PdfPfade aus dem PDF (Vektordaten).

  Geprüft wird:
    Es gibt mindestens eine solche Spitze in der Nähe einer Tür. Türen erkennt man am Schwenkbogen (viertelkreisförmiger
    Bogen im PDF, 10 bis 60 Punkt groß). "In der Nähe" heißt: höchstens 2,5 Türbreiten vom Bogen entfernt.
  Ohne Pfeil in der Nähe einer Tür kommt ein Befund. Welche Tür die Eingangstür ist und ob der Pfeil in die richtige
  Richtung zeigt, wird nicht geprüft. Mehrere Pfeile sind in Ordnung.
  Ist im Plan gar kein Türbogen zu finden, wird jede Pfeilspitze im Plan gezählt (Hinweis im Ergebnis).
#>

# Pfeilspitzen aus den Strichen: Liste mit X, Y (Spitze), Winkel (Öffnungswinkel) und Richtung (Grad, Winkelhalbierende)
function Get-PfeilSpitzen($linien) {
    $kurz = @($linien | Where-Object { $_.Laenge -ge 2.5 -and $_.Laenge -le 30 -and [math]::Abs($_.X1 - $_.X2) -gt 0.4 -and [math]::Abs($_.Y1 - $_.Y2) -gt 0.4 })
    $spitzen = New-Object System.Collections.Generic.List[object]
    # Endpunkte in Fächer (1 Punkt Raster) sortieren, damit nur Striche verglichen werden, die sich berühren können
    $fach = @{}
    for ($i = 0; $i -lt $kurz.Count; $i++) {
        foreach ($ende in 1, 2) {
            $px = if ($ende -eq 1) { $kurz[$i].X1 } else { $kurz[$i].X2 }; $py = if ($ende -eq 1) { $kurz[$i].Y1 } else { $kurz[$i].Y2 }
            $k = "$([int][math]::Floor($px)),$([int][math]::Floor($py))"
            if (-not $fach.ContainsKey($k)) { $fach[$k] = New-Object System.Collections.Generic.List[object] }
            $fach[$k].Add([pscustomobject]@{ I = $i; Ende = $ende; X = $px; Y = $py })
        }
    }
    foreach ($e1 in @($fach.Values | ForEach-Object { $_ })) {
        $a = $kurz[$e1.I]; $px = $e1.X; $py = $e1.Y
        $ax = if ($e1.Ende -eq 1) { $a.X2 - $a.X1 } else { $a.X1 - $a.X2 }; $ay = if ($e1.Ende -eq 1) { $a.Y2 - $a.Y1 } else { $a.Y1 - $a.Y2 }
        $la = [math]::Sqrt($ax * $ax + $ay * $ay)
        $fx = [int][math]::Floor($px); $fy = [int][math]::Floor($py)
        foreach ($dx in -1, 0, 1) { foreach ($dy in -1, 0, 1) {
                $k = "$($fx + $dx),$($fy + $dy)"
                if (-not $fach.ContainsKey($k)) { continue }
                foreach ($e2 in $fach[$k]) {
                    if ($e2.I -le $e1.I) { continue }
                    if ([math]::Abs($e2.X - $px) -ge 0.3 -or [math]::Abs($e2.Y - $py) -ge 0.3) { continue }
                    $b = $kurz[$e2.I]
                    $bx = if ($e2.Ende -eq 1) { $b.X2 - $b.X1 } else { $b.X1 - $b.X2 }; $by = if ($e2.Ende -eq 1) { $b.Y2 - $b.Y1 } else { $b.Y1 - $b.Y2 }
                    $lb = [math]::Sqrt($bx * $bx + $by * $by)
                    if ([math]::Abs($la - $lb) -gt 0.25 * [math]::Max($la, $lb)) { continue }
                    $cos = ($ax * $bx + $ay * $by) / ($la * $lb)
                    $w = [math]::Acos([math]::Max(-1, [math]::Min(1, $cos))) * 180 / [math]::PI
                    if ($w -lt 40 -or $w -gt 130) { continue }
                    $mx = $ax / $la + $bx / $lb; $my = $ay / $la + $by / $lb
                    if ([math]::Sqrt($mx * $mx + $my * $my) -lt 0.01) { continue }
                    $ang = [math]::Atan2($my, $mx) * 180 / [math]::PI
                    $abw = [math]::Abs((($ang % 90) + 90) % 90); $abw = [math]::Min($abw, 90 - $abw)
                    if ($abw -gt 12) { continue }
                    $spitzen.Add([pscustomobject]@{ X = $px; Y = $py; Winkel = [math]::Round($w); Richtung = [math]::Round($ang); Laenge = $la })
                }
            } }
    }    # Dieselbe Spitze nur einmal
    $einzeln = New-Object System.Collections.Generic.List[object]
    foreach ($s in $spitzen) { if (-not @($einzeln | Where-Object { [math]::Abs($_.X - $s.X) -lt 1 -and [math]::Abs($_.Y - $s.Y) -lt 1 }).Count) { $einzeln.Add($s) } }
    $einzeln.ToArray()
}

# Türbögen (Schwenkbereich einer Tür): gekrümmte Striche, 10 bis 60 Punkt breit und hoch
function Get-TuerBoegen($pfade) {
    @($pfade | Where-Object { $_.Kurve -and $_.Art -eq 'strich' -and ($_.X1 - $_.X0) -ge 10 -and ($_.Y1 - $_.Y0) -ge 10 })
}

# Gerade Striche (zwei Punkte) aus den Pfaden, für die Pfeilspitzen
function Get-PfadStriche($pfade) {
    foreach ($p in @($pfade | Where-Object { $_.Art -eq 'strich' -and -not $_.Kurve -and $_.Teile.Count -eq 1 -and $_.Teile[0].Count -eq 2 })) {
        $a = $p.Teile[0][0]; $b = $p.Teile[0][1]
        [pscustomobject]@{ X1 = $a.X; Y1 = $a.Y; X2 = $b.X; Y2 = $b.Y; Laenge = [math]::Sqrt([math]::Pow($b.X - $a.X, 2) + [math]::Pow($b.Y - $a.Y, 2)) }
    }
}

function Get-A8Eingangspfeil($pfade) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $spitzen = @(Get-PfeilSpitzen @(Get-PfadStriche $pfade))
    $boegen = @(Get-TuerBoegen $pfade)
    if ($spitzen.Count -eq 0) {
        $ergebnisse.Add((New-Result 'Eingangspfeil' $false '' 'Im Plan ist kein Eingangspfeil zu finden (Pfeil oder Dreieck vor der Eingangstür).'))
        return $ergebnisse
    }
    if ($boegen.Count -eq 0) {
        $s = $spitzen[0]
        $ergebnisse.Add((New-Result 'Eingangspfeil' $true "$($spitzen.Count) Pfeilspitze(n) im Plan, keine Tür zum Abgleich gefunden" '' $s.X $s.Y))
        return $ergebnisse
    }
    $nah = @()
    foreach ($s in $spitzen) {
        foreach ($b in $boegen) {
            $breite = [math]::Max($b.X1 - $b.X0, $b.Y1 - $b.Y0)
            # Abstand von der Spitze zum Umfassungsrechteck des Bogens
            $dx = [math]::Max([math]::Max($b.X0 - $s.X, 0), $s.X - $b.X1); $dy = [math]::Max([math]::Max($b.Y0 - $s.Y, 0), $s.Y - $b.Y1)
            if ([math]::Sqrt($dx * $dx + $dy * $dy) -gt 2.5 * $breite) { continue }
            # Der Pfeil zeigt in Richtung Tür: die Mitte des Bogens liegt vor der Spitze (Winkel zur Pfeilrichtung höchstens 60 Grad)
            $vx = ($b.X0 + $b.X1) / 2 - $s.X; $vy = ($b.Y0 + $b.Y1) / 2 - $s.Y
            $zeigX = -[math]::Cos($s.Richtung * [math]::PI / 180); $zeigY = -[math]::Sin($s.Richtung * [math]::PI / 180)
            $lv = [math]::Sqrt($vx * $vx + $vy * $vy)
            if ($lv -lt 0.5 -or (($vx * $zeigX + $vy * $zeigY) / $lv) -ge 0.5) { $nah += $s; break }
        }
    }    if ($nah.Count -gt 0) {
        $s = $nah[0]
        $ergebnisse.Add((New-Result 'Eingangspfeil' $true "$($nah.Count) Pfeil(e) an einer Tür" '' $s.X $s.Y))
    } else {
        $ergebnisse.Add((New-Result 'Eingangspfeil' $false '' 'Es gibt Pfeilspitzen oder Dreiecke im Plan, aber keine in der Nähe einer Tür. Der Eingangspfeil soll vor der Eingangstür stehen.' $spitzen[0].X $spitzen[0].Y))
    }
    $ergebnisse
}

$script:Pruefungen += @{
    Id     = 'A8'
    Name   = 'Eingangspfeil'
    Phasen = @('entwurf', 'werk')
    Run    = { param($items, $pdfPfad) $p = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $p = @(Get-PdfPfadeCached $pdfPfad) }; Get-A8Eingangspfeil $p }
}
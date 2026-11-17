<#
  A9 Achsen (nur Werkplanung): Ist ein Achsraster im Plan vorhanden?

  Entscheidung vom Team (17.11.): Eine Achse erkennt man an den Linien. Mehrere Strichpunktlinien
  (oder Strichlinien), die waagrecht und/oder senkrecht durch das Gebäude laufen, bilden das Raster.
  Achsbezeichnungen (Buchstaben und/oder Zahlen in Kreisen) können vorhanden sein, ihr Fehlen ist
  KEIN Fehler. Auch Lücken oder Vollständigkeit der Bezeichnungen werden nicht geprüft.

  Wie die Linien gefunden werden (siehe Get-PdfLinien in pdf-grafik.ps1): In ArchiCAD-PDFs besteht eine
  Strichpunktlinie aus vielen einzelnen kurzen Strichen (lange Striche und Punkte). Gesucht wird eine
  Kette waagrechter oder senkrechter Striche auf einer Linie, bei der
    - die Striche lückenlos aneinander anschließen (Lücke höchstens 12 Punkt),
    - die Kette mindestens 300 Punkt lang ist (ein Stück Gebäude, keine Maßkette),
    - die langen Striche (mindestens 5 Punkt) fast alle gleich lang sind (mindestens 85 Prozent) und
      zwischen ihnen Punkte stehen (Strichpunkt, mindestens 20 Prozent Punkte),
      oder bei einer reinen Strichlinie (ohne Punkte) die Striche mindestens 8 Punkt lang, mindestens 95 Prozent
      gleich lang sind und die Kette mindestens 500 Punkt lang ist.
  Mehrere solche Linien in einer Richtung sind ein Raster. Genau eine einzelne Linie reicht nicht (Befund),
  keine Linie ist ein Befund.
#>

# Findet Achsenlinien in den Strichen eines Plans. Liefert Richtung ('senkrecht'/'waagrecht'), Lage, Von, Bis, Anzahl.
# Merkt sich das Ergebnis für dieselben Linien (A2, A5 und A9 brauchen die Achsen, die Suche dauert einige Sekunden)
$script:AchsenCache = @{}
function Get-AchsenLinien($linien) {
    $liste = @($linien)
    $schluessel = if ($liste.Count -gt 0) { "$($liste.Count)|$($liste[0].X1)|$($liste[0].Y1)|$($liste[$liste.Count - 1].X2)|$($liste[$liste.Count - 1].Y2)" } else { 'leer' }
    if (-not $script:AchsenCache.ContainsKey($schluessel)) { $script:AchsenCache = @{}; $script:AchsenCache[$schluessel] = @(Get-AchsenLinienNeu $liste) }
    $script:AchsenCache[$schluessel]
}

function Get-AchsenLinienNeu($linien) {
    $achsen = @()
    foreach ($richt in 'senkrecht', 'waagrecht') {
        $sel = if ($richt -eq 'senkrecht') { @($linien | Where-Object { [math]::Abs($_.X1 - $_.X2) -lt 0.05 }) } else { @($linien | Where-Object { [math]::Abs($_.Y1 - $_.Y2) -lt 0.05 }) }
        $teile = @($sel | ForEach-Object {
                if ($richt -eq 'senkrecht') { [pscustomobject]@{ K = [math]::Round($_.X1, 1); A = [math]::Min($_.Y1, $_.Y2); B = [math]::Max($_.Y1, $_.Y2) } }
                else { [pscustomobject]@{ K = [math]::Round($_.Y1, 1); A = [math]::Min($_.X1, $_.X2); B = [math]::Max($_.X1, $_.X2) } }
            })
        foreach ($g in @($teile | Group-Object K)) {
            if ($g.Count -lt 15) { continue }
            $s = @($g.Group | Sort-Object A)
            $ketten = @(); $akt = @($s[0]); $ende = $s[0].B
            for ($i = 1; $i -lt $s.Count; $i++) {
                if (($s[$i].A - $ende) -le 12) { $akt += $s[$i]; $ende = [math]::Max($ende, $s[$i].B) }
                else { $ketten += , $akt; $akt = @($s[$i]); $ende = $s[$i].B }
            }
            $ketten += , $akt
            foreach ($k in $ketten) {
                $von = ($k | Measure-Object A -Minimum).Minimum; $bis = ($k | Measure-Object B -Maximum).Maximum
                $ext = $bis - $von
                if ($k.Count -lt 15 -or $ext -lt 300) { continue }
                $laengen = @($k | ForEach-Object { $_.B - $_.A })
                $punkte = @($laengen | Where-Object { $_ -le 0.5 }).Count
                $lang = @($laengen | Where-Object { $_ -gt 0.5 } | Sort-Object)
                if ($lang.Count -lt 5) { continue }
                $med = $lang[[int]($lang.Count / 2)]
                $gleich = @($lang | Where-Object { [math]::Abs($_ - $med) -le 0.1 * $med }).Count / $lang.Count
                $strichpunkt = ($med -ge 5 -and $gleich -ge 0.85 -and $punkte -ge 0.2 * $k.Count)
                $strich = ($punkte -eq 0 -and $med -ge 8 -and $gleich -ge 0.95 -and $ext -ge 500)
                if ($strichpunkt -or $strich) {
                    $achsen += [pscustomobject]@{ Richtung = $richt; Lage = $g.Group[0].K; Von = $von; Bis = $bis; Anzahl = $k.Count }
                }
            }
        }
    }
    # Gleiche Linie, die in mehreren Teilen vorkommt, nur einmal zählen (gleiche Richtung, Lage um weniger als 1,5 Punkt)
    $einzeln = @()
    foreach ($a in @($achsen | Sort-Object Richtung, Lage)) {
        $doppelt = @($einzeln | Where-Object { $_.Richtung -eq $a.Richtung -and [math]::Abs($_.Lage - $a.Lage) -lt 1.5 }).Count -gt 0
        if (-not $doppelt) { $einzeln += $a }
    }
    $einzeln
}

# Achsbezeichnungen (nur zur Information, ihr Fehlen ist kein Fehler): einzelne Großbuchstaben oder Ziffern,
# die an einem Ende einer gefundenen Achsenlinie stehen (in einem Kreis, wenige Punkt neben dem Linienende).
function Get-AchsBezeichnungen($items, $achsen) {
    $namen = @()
    foreach ($a in $achsen) {
        foreach ($i in @($items | Where-Object { $_.T -cmatch '^[A-Z1-9]$' })) {
            $quer = if ($a.Richtung -eq 'senkrecht') { $i.X } else { $i.Y }
            $laengs = if ($a.Richtung -eq 'senkrecht') { $i.Y } else { $i.X }
            if ([math]::Abs($quer - $a.Lage) -le 6 -and ([math]::Abs($laengs - $a.Von) -le 40 -or [math]::Abs($laengs - $a.Bis) -le 40)) { $namen += $i.T }
        }
    }
    @($namen | Select-Object -Unique | Sort-Object)
}
function Get-A9Achsen($items, $linien) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $achsen = @(Get-AchsenLinien @($linien))
    $senk = @($achsen | Where-Object { $_.Richtung -eq 'senkrecht' })
    $waag = @($achsen | Where-Object { $_.Richtung -eq 'waagrecht' })
    $namen = @(Get-AchsBezeichnungen $items $achsen)
    $info = if ($namen.Count -gt 0) { "Bezeichnungen: $($namen -join ', ')" } else { 'ohne Bezeichnungen' }

    if ($achsen.Count -eq 0) {
        $ergebnisse.Add((New-Result 'Achsen' $false '' 'Im Plan ist kein Achsraster zu finden (keine Strichpunkt- oder Strichlinien, die waagrecht oder senkrecht durch das Gebäude laufen).'))
    } elseif ($senk.Count -lt 2 -and $waag.Count -lt 2) {
        $a = $achsen[0]
        $x = if ($a.Richtung -eq 'senkrecht') { $a.Lage } else { $a.Von }
        $y = if ($a.Richtung -eq 'senkrecht') { $a.Von } else { $a.Lage }
        $ergebnisse.Add((New-Result 'Achsen' $false '1 Linie' 'Es wurde nur eine einzelne Achsenlinie gefunden. Ein Achsraster besteht aus mehreren Strichpunkt- oder Strichlinien.' $x $y))
    } else {
        $a = if ($senk.Count -ge 2) { $senk[0] } else { $waag[0] }
        $x = if ($a.Richtung -eq 'senkrecht') { $a.Lage } else { $a.Von }
        $y = if ($a.Richtung -eq 'senkrecht') { $a.Von } else { $a.Lage }
        $ergebnisse.Add((New-Result 'Achsen' $true "$($senk.Count) senkrechte, $($waag.Count) waagrechte Achsenlinien ($info)" '' $x $y))
    }
    $ergebnisse
}

$script:Pruefungen += @{
    Id     = 'A9'
    Name   = 'Achsen'
    Phasen = @('werk')
    Run    = { param($items, $pdfPfad) $l = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $l = @(Get-PdfLinienCached $pdfPfad) }; Get-A9Achsen $items $l }
}
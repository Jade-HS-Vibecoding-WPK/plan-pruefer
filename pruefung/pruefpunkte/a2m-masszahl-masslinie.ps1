<#
  A2M Maßzahl zu Maßlinie (nur Werkplanung)

  Im PDF besteht jede Maßkette aus einzelnen Maßlinien-Stücken mit kurzen Querstrichen (Maßhilfslinien) an den Enden.
  Über jedem Stück steht seine Maßzahl. Die Länge des Stücks (Punkt mal Maßstab) muss die Zahl ergeben. Das gilt für
  die Ketten außen und innen im Gebäude (Wand-Maßketten).

  Gelesen werden Maßzahlen in Metern (1,53), in Zentimetern ohne Komma (78 oder 13) und mit hochgestellter 5
  (halber Zentimeter, 1,65 mit kleiner 5 daneben = 1,655 m). Zu jeder Zahl wird das Maßlinien-Stück gesucht, das knapp
  unter ihr (waagrechter Text) oder daneben (senkrechter Text) liegt, die Zahl in der Mitte hat und an beiden Enden einen
  Begrenzungs-Querstrich (Maßhilfslinie) trägt (Stücke am Kettenende mit nur einem Strich werden nicht beachtet).

  Geprüft wird:
    - Stimmt die Länge mit der Zahl überein (1 cm Toleranz)? Dann ist die Zahl in Ordnung.
    - Gemessen wird von Querstrich zu Querstrich, nicht die Länge des Linienstücks: ArchiCAD teilt die Linie etwas neben
      dem Querstrich (im Musterplan 2,5 cm), am Kettenende wäre das Stück sonst 5 cm zu kurz (geklärt mit dem Team 18.11.).
    - Alles andere ist ein Befund: Die Zahl passt nicht zur Maßlinie (eine Zahl ist falsch, oder die Linie).
  Zahlen ohne passendes Maßlinien-Stück (Raumstempel, Höhen, Beschriftungen) werden nicht beachtet.
  Noch nicht geprüft: Maßlinien ohne Zahl, fehlende ganze Innenketten.
#>

$script:A2mZeichenbreite = 4.25
$script:A2mToleranz = 0.011

function Get-A2mZahlen($items) {
    $kand = @($items | Where-Object { $_.T -match '^\d{1,3},\d{2}$' -or $_.T -match '^\d{1,2}$' })
    $verbraucht = New-Object System.Collections.Generic.HashSet[object]
    $hoch = @{}
    foreach ($s in @($kand | Where-Object { $_.T -match '^\d$' })) {
        foreach ($n in $kand) {
            if ($n -eq $s -or $n.T.Length -lt 2) { continue }
            $w = $n.T.Length * $script:A2mZeichenbreite
            $dx = $s.X - $n.X; $dy = $s.Y - $n.Y
            $waag = ($dx -ge $w - 4.5 -and $dx -le $w + 4.5 -and $dy -ge -4.5 -and $dy -le -1.5)
            $senk = ($dx -ge -4.5 -and $dx -le -1.5 -and $dy -ge -$w - 4.5 -and $dy -le -$w + 4.5)
            if ($waag -or $senk) { [void]$verbraucht.Add($s); $hoch[$n] = [int]$s.T; break }
        }
    }
    foreach ($n in $kand) {
        if ($verbraucht.Contains($n)) { continue }
        $wert = if ($n.T -match ',') { [double]::Parse(($n.T -replace ',', '.'), [System.Globalization.CultureInfo]::InvariantCulture) } else { [double]$n.T / 100 }
        if ($hoch.ContainsKey($n)) { $wert += $hoch[$n] * 0.001 }
        [pscustomobject]@{ Item = $n; Wert = $wert; Text = $n.T; Breite = $n.T.Length * $script:A2mZeichenbreite }
    }
}

# Maßzahlen mit ihren Maßlinien-Stücken. Pro Zahl: Zahl (aus Get-A2mZahlen), Richtung ('h' waagrecht, 'v' senkrecht),
# Stueck (Q = Lage der Linie, A bis B = Anfang und Ende), LaengeM (Länge in Metern), Passt (Zahl und Länge stimmen überein).
# Wird auch von A5 (Flächen gegen Wandmaße) genutzt.
# Merkt sich das Ergebnis (A2M und A5 brauchen die Stücke)
$script:A2mCache = @{}
function Get-A2mStuecke($items, $linien) {
    $li = @($linien); $it = @($items)
    $schluessel = "$($it.Count)|$(($it | ForEach-Object { $_.T }) -join '~')|$($li.Count)|$(if ($li.Count) { "$($li[0].X1)|$($li[$li.Count - 1].Y2)" })"
    if (-not $script:A2mCache.ContainsKey($schluessel)) { $script:A2mCache = @{}; $script:A2mCache[$schluessel] = @(Get-A2mStueckeNeu $it $li) }
    $script:A2mCache[$schluessel]
}

function Get-A2mStueckeNeu($items, $linien) {
    $massstab = Get-A2Massstab $items
    $ptZuM = 0.352778 / 1000 * $massstab
    $zahlen = @(Get-A2mZahlen $items)

    # Linien: waagrecht (Q = Y) und senkrecht (Q = X) in Fächern nach Q, dazu die schrägen Begrenzungsstriche
    $h = @{}; $v = @{}
    foreach ($l in $linien) {
        if ($l.Laenge -lt 3) { continue }
        if ([math]::Abs($l.Y1 - $l.Y2) -lt 0.05) { $k = [int][math]::Floor($l.Y1); if (-not $h.ContainsKey($k)) { $h[$k] = New-Object System.Collections.Generic.List[object] }; $h[$k].Add([pscustomobject]@{ Q = $l.Y1; A = [math]::Min($l.X1, $l.X2); B = [math]::Max($l.X1, $l.X2); L = $l.Laenge }) }
        elseif ([math]::Abs($l.X1 - $l.X2) -lt 0.05) { $k = [int][math]::Floor($l.X1); if (-not $v.ContainsKey($k)) { $v[$k] = New-Object System.Collections.Generic.List[object] }; $v[$k].Add([pscustomobject]@{ Q = $l.X1; A = [math]::Min($l.Y1, $l.Y2); B = [math]::Max($l.Y1, $l.Y2); L = $l.Laenge }) }
    }
    # Begrenzung der Maßlinien-Stücke: ein kurzer Strich (4 bis 16 Punkt) mittig auf dem Ende des Stücks. Entweder ein gerader
    # Querstrich (Maßhilfslinie, so im Musterplan) oder ein schräger Strich (Schrägstrich nach DIN, so in anderen Plänen).
    $querFach = @{}; $schraegFach = @{}
    foreach ($l in $linien) {
        if ($l.Laenge -lt 4 -or $l.Laenge -gt 16) { continue }
        $dx = [math]::Abs($l.X1 - $l.X2); $dy = [math]::Abs($l.Y1 - $l.Y2)
        if ($dx -lt 0.05) { $art = 'v'; $q = $l.X1; $a1 = [math]::Min($l.Y1, $l.Y2); $b1 = [math]::Max($l.Y1, $l.Y2) }
        elseif ($dy -lt 0.05) { $art = 'h'; $q = $l.Y1; $a1 = [math]::Min($l.X1, $l.X2); $b1 = [math]::Max($l.X1, $l.X2) }
        elseif ($dx / $dy -ge 0.5 -and $dx / $dy -le 2) {
            $mx = ($l.X1 + $l.X2) / 2; $my = ($l.Y1 + $l.Y2) / 2
            $k = "$([int][math]::Floor($mx / 4))|$([int][math]::Floor($my / 4))"
            if (-not $schraegFach.ContainsKey($k)) { $schraegFach[$k] = New-Object System.Collections.Generic.List[object] }
            $schraegFach[$k].Add([pscustomobject]@{ X = $mx; Y = $my })
            continue
        }
        else { continue }
        $k = "$art$([int][math]::Floor($q / 4))"
        if (-not $querFach.ContainsKey($k)) { $querFach[$k] = New-Object System.Collections.Generic.List[object] }
        $querFach[$k].Add([pscustomobject]@{ Q = $q; A = $a1; B = $b1 })
    }
    # Ende einer waagrechten Maßlinie bei (x, y): senkrechter Querstrich bei x, der mittig auf y sitzt. Ende einer senkrechten:
    # waagrechter Querstrich bei y, mittig auf x. Oder ein schräger Strich mit Mitte auf dem Ende.
    # Liefert die Lage des Strichs (oder $null). ArchiCAD teilt die Linienstücke nicht genau am geraden Querstrich, sondern
    # etwas versetzt (im Musterplan 1,42 Punkt = 2,5 cm bei 1:50). Gemessen wird deshalb von Strich zu Strich.
    # Nicht mittig sitzende Striche (Wandlinien, Hilfslinien von Bauteilen) zählen nicht: lieber kein Befund als ein falscher.
    $tickBei = {
        param($art, $x, $y)
        $pos = if ($art -eq 'h') { $x } else { $y }; $quer2 = if ($art -eq 'h') { $y } else { $x }
        $gesucht = if ($art -eq 'h') { 'v' } else { 'h' }
        # Rang: mittig und mindestens 6 Punkt lang (gestrichelte Hilfslinien haben kürzere Striche) vor nur mittig
        $mittig = $null; $mittigD = 99; $lang = $null; $langD = 99
        foreach ($dk in -1, 0, 1) {
            $k = "$gesucht$([int][math]::Floor($pos / 4) + $dk)"
            if ($querFach.ContainsKey($k)) {
                foreach ($s in $querFach[$k]) {
                    $dd = [math]::Abs($s.Q - $pos)
                    if ($dd -gt 3 -or [math]::Abs(($s.A + $s.B) / 2 - $quer2) -gt 0.6) { continue }
                    if ($dd -lt $mittigD) { $mittig = $s.Q; $mittigD = $dd }
                    if (($s.B - $s.A) -ge 6 -and $dd -lt $langD) { $lang = $s.Q; $langD = $dd }
                }
            }
        }
        if ($null -ne $lang) { return $lang }
        if ($null -ne $mittig) { return $mittig }
        foreach ($di in -1, 0, 1) {
            foreach ($dj in -1, 0, 1) {
                $k = "$([int][math]::Floor($x / 4) + $di)|$([int][math]::Floor($y / 4) + $dj)"
                if ($schraegFach.ContainsKey($k)) {
                    foreach ($s in $schraegFach[$k]) {
                        if ([math]::Abs($s.X - $x) -le 1 -and [math]::Abs($s.Y - $y) -le 1) { return $(if ($art -eq 'h') { $s.X } else { $s.Y }) }
                    }
                }
            }
        }
        $null
    }
    # Stück von Querstrich zu Querstrich (oder $null, wenn ein Ende keinen Querstrich hat)
    $zuStueck = {
        param($art, $s)
        if ($art -eq 'h') { $ta = & $tickBei 'h' $s.A $s.Q; $tb = & $tickBei 'h' $s.B $s.Q } else { $ta = & $tickBei 'v' $s.Q $s.A; $tb = & $tickBei 'v' $s.Q $s.B }
        if ($null -eq $ta -or $null -eq $tb -or $tb -le $ta) { return $null }
        [pscustomobject]@{ Q = $s.Q; A = $ta; B = $tb; L = $tb - $ta; LStueck = $s.L }
    }
    foreach ($z in $zahlen) {
        $n = $z.Item
        $kandidaten = New-Object System.Collections.Generic.List[object]
        # waagrechter Text: Maßlinie knapp darunter (0 bis 4 Punkt), Mitte der Zahl über dem Stück
        $cx = $n.X + $z.Breite / 2
        foreach ($k in ([int][math]::Floor($n.Y - 1))..([int][math]::Floor($n.Y + 4))) {
            if (-not $h.ContainsKey($k)) { continue }
            foreach ($s in $h[$k]) {
                $d = $s.Q - $n.Y
                if ($d -ge -1 -and $d -le 4 -and $cx -ge ($s.A - 0.5) -and $cx -le ($s.B + 0.5)) { $t = & $zuStueck 'h' $s; if ($t) { $kandidaten.Add([pscustomobject]@{ Richtung = 'h'; S = $t }) } }
            }
        }
        # senkrechter Text (von unten nach oben gelesen): Maßlinie knapp rechts daneben, Mitte der Zahl über dem Stück
        $cy = $n.Y - $z.Breite / 2
        foreach ($k in ([int][math]::Floor($n.X - 1))..([int][math]::Floor($n.X + 4))) {
            if (-not $v.ContainsKey($k)) { continue }
            foreach ($s in $v[$k]) {
                $d = $s.Q - $n.X
                if ($d -ge -1 -and $d -le 4 -and $cy -ge ($s.A - 0.5) -and $cy -le ($s.B + 0.5)) { $t = & $zuStueck 'v' $s; if ($t) { $kandidaten.Add([pscustomobject]@{ Richtung = 'v'; S = $t }) } }
            }
        }
        if ($kandidaten.Count -eq 0) { continue }
        $passt = @($kandidaten | Where-Object { $diff = $z.Wert - $_.S.L * $ptZuM; [math]::Abs($diff) -le $script:A2mToleranz })
        $wahl = if ($passt.Count -gt 0) { $passt[0] } else { $kandidaten | Sort-Object { [math]::Abs($z.Wert - $_.S.L * $ptZuM) } | Select-Object -First 1 }
        [pscustomobject]@{ Zahl = $z; Richtung = $wahl.Richtung; Stueck = $wahl.S; LaengeM = $wahl.S.L * $ptZuM; Passt = ($passt.Count -gt 0) }
    }
}

function Get-A2mPruefung($items, $linien) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $geprueft = 0; $befunde = 0
    foreach ($st in @(Get-A2mStuecke $items $linien)) {
        $z = $st.Zahl; $n = $z.Item
        # Nur Zahlen in Metern (mit Komma) werden geprüft: Zentimeterzahlen (zum Beispiel Wandstärken) sind zu leicht mit anderen Zahlen zu verwechseln
        if ($z.Text -notmatch ',') { continue }
        $geprueft++
        if ($st.Passt) { continue }
        $lm = $st.LaengeM
        # Die Linie muss ungefähr zur Zahl gehören (0,6 bis 1,7 fach), sonst ist es nur eine zufällig darunter liegende Linie
        if ($lm -lt 0.6 * $z.Wert -or $lm -gt 1.7 * $z.Wert) { continue }
        $befunde++
        $ergebnisse.Add((New-Result "Maßzahl $($z.Text)" $false $z.Text "Die Maßzahl $($z.Text) passt nicht zur Maßlinie darunter: Die Linie ist $($lm.ToString('0.00', (New-Object System.Globalization.CultureInfo('de-DE')))) m lang. Die Zahl oder die Linie ist falsch." $n.X $n.Y))
    }
    if ($befunde -eq 0) { $ergebnisse.Add((New-Result 'Maßzahlen zu Maßlinien' $true "$geprueft Maßzahlen stimmen mit ihren Maßlinien überein" '')) }
    $ergebnisse | Sort-Object { $_.Ok }
}
$script:Pruefungen += @{
    Id     = 'A2M'
    Name   = 'Maßzahl zu Maßlinie'
    Phasen = @('werk')
    Run    = { param($items, $pdfPfad) $l = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $l = @(Get-PdfLinienCached $pdfPfad) }; Get-A2mPruefung $items $l }
}
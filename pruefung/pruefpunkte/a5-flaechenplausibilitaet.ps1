<#
  A5 Flächenplausibilität (nur Werkplanung)

  Im Werkplan steht im Raumstempel NGF (Fläche) und RU (Umfang) je Raum, am Gebäude das Gesamtmaß (A2).
  Daraus lässt sich prüfen, ob die Zahlen zusammenpassen. Gelesen werden die Stempel wie bei A4W.

  Geprüft wird (nur was im Plan steht, fehlende Angaben sind kein Fehler):
    1. Fläche je Raum mindestens 0,5 m².
    2. Umfang zur Fläche: Kein Raum hat einen kleineren Umfang als ein Quadrat gleicher Fläche (RU mindestens
       4 mal Wurzel aus NGF, 1,5 Prozent Toleranz). Ein Umfang über dem 2,5-fachen des Quadrat-Umfangs (sehr langer, schmaler Raum) ist unwahrscheinlich.
    3. Summe aller Raumflächen höchstens so groß wie das Rechteck aus den Gesamtmaßen (Breite mal Tiefe).
       Liegt die Summe unter 40 Prozent dieses Rechtecks, kommt ein Hinweis (fehlt ein Raum?).
       Ohne Achsraster oder ohne Gesamtmaß entfällt dieser Teil.
#>

function Get-A5Flaechen($items, $linien) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $stempel = @(Get-A4WRaumstempel $items)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $de = New-Object System.Globalization.CultureInfo('de-DE')
    $summe = 0.0; $anzahl = 0

    foreach ($s in $stempel) {
        $raum = if ($s.NameText) { $s.NameText } elseif ($s.Nummer) { "Nr. $($s.Nummer.T)" } else { '(ohne Namen)' }
        $posX = if ($s.Name) { $s.Name.X } else { $s.AnkerX }
        $posY = if ($s.Name) { $s.Name.Y } else { $s.Oben - 29 }
        $ngfItem = $s.Felder['NGF'].Wert; $ruItem = $s.Felder['RU'].Wert
        if (-not $ngfItem) { continue }
        $ngf = 0.0; [void][double]::TryParse(($ngfItem.T -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$ngf)
        if ($ngf -le 0) { continue }   # das meldet A4
        $summe += $ngf; $anzahl++
        $probleme = 0

        if ($ngf -lt 0.5) {
            $ergebnisse.Add((New-Result "Raum $raum" $false "$($ngfItem.T) m²" "Raum ${raum}: Die Fläche $($ngfItem.T) m² ist unwahrscheinlich klein (unter 0,5 m²)." $ngfItem.X $ngfItem.Y)); $probleme++
        }
        if ($ruItem) {
            $ru = 0.0; [void][double]::TryParse(($ruItem.T -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$ru)
            if ($ru -gt 0) {
                $minRu = 4 * [math]::Sqrt($ngf)
                $maxRu = 2.5 * $minRu
                if ($ru -lt $minRu * 0.985) {
                    $ergebnisse.Add((New-Result "Raum $raum" $false "NGF $($ngfItem.T), RU $($ruItem.T)" "Raum ${raum}: Der Umfang $($ruItem.T) m ist für die Fläche $($ngfItem.T) m² zu klein (selbst ein Quadrat hat $($minRu.ToString('0.00', $de)) m Umfang). Fläche oder Umfang ist falsch." $ruItem.X $ruItem.Y)); $probleme++
                } elseif ($ru -gt $maxRu) {
                    $ergebnisse.Add((New-Result "Raum $raum" $false "NGF $($ngfItem.T), RU $($ruItem.T)" "Raum ${raum}: Der Umfang $($ruItem.T) m ist für die Fläche $($ngfItem.T) m² unwahrscheinlich groß. Fläche oder Umfang ist falsch." $ruItem.X $ruItem.Y)); $probleme++
                }
            }
        }
        if ($probleme -eq 0) { $ergebnisse.Add((New-Result "Raum $raum" $true "$($ngfItem.T) m²$(if ($ruItem) { ", RU $($ruItem.T) m" })" '' $posX $posY)) }
    }

    # Summe der Räume gegen das Gebäude
    $gm = Get-A2Gesamtmasse $items $linien
    if ($anzahl -gt 0 -and $gm -and $gm.Breite -gt 0 -and $gm.Tiefe -gt 0) {
        $rechteck = $gm.Breite * $gm.Tiefe
        $text = "Summe der Raumflächen $($summe.ToString('0.00', $de)) m², Gebäuderechteck $($gm.Breite.ToString('0.00', $de)) mal $($gm.Tiefe.ToString('0.00', $de)) m = $($rechteck.ToString('0.00', $de)) m²"
        if ($summe -gt $rechteck) {
            $ergebnisse.Add((New-Result 'Raumflächen gesamt' $false $text "Die Raumflächen ergeben zusammen $($summe.ToString('0.00', $de)) m², das ist mehr als das Gebäude nach den Gesamtmaßen groß ist ($($rechteck.ToString('0.00', $de)) m²). Eine Fläche ist zu groß oder ein Gesamtmaß falsch."))
        } elseif ($summe -lt 0.4 * $rechteck) {
            $ergebnisse.Add((New-Result 'Raumflächen gesamt' $false $text "Die Raumflächen decken nur $([math]::Round(100 * $summe / $rechteck)) Prozent des Gebäuderechtecks ab. Fehlt ein Raum oder eine Fläche?"))
        } else {
            $ergebnisse.Add((New-Result 'Raumflächen gesamt' $true $text ''))
        }
    }
    $ergebnisse | Sort-Object { $_.Ok }
}

<#
  A5 Stufe 2: NGF und RU gegen die Wand-Maßketten im Gebäude (Wunsch vom Team, Hinweis ab 3 Prozent Abweichung)

  Die Maßzahlen im Gebäude mit ihren Maßlinien liefert A2M (Get-A2mStuecke, nur Zahlen, deren Linie genau passt).
  Zu jedem Raumstempel werden die nächsten Maßketten gesucht, die am Stempel vorbeilaufen: bis zu drei senkrechte
  (die Linie reicht über die Höhe des Stempels) und drei waagrechte (die Linie reicht über die Breite des Stempels),
  jeweils höchstens 250 Punkt entfernt. Dann wird gerechnet:
    - zwei Maße (eins senkrecht, eins waagrecht): Breite mal Länge gegen NGF, 2 mal (Breite plus Länge) gegen RU
    - ein Maß d: die andere Seite ist RU/2 minus d, d mal andere Seite gegen NGF
  Die am besten passende Rechnung zählt. Abweichung bis 3 Prozent: in Ordnung. 3 bis 15 Prozent: Hinweis (gelb, kein
  sicherer Fehler). Über 15 Prozent oder keine Maßkette: nicht nachprüfbar (der Raum ist wohl nicht rechteckig, oder
  die Maße gehören zu einem anderen Raum), dann wird nichts gemeldet.
#>
function Get-A5Wandmasse($items, $linien) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $de = New-Object System.Globalization.CultureInfo('de-DE')
    $stuecke = @(Get-A2mStuecke $items $linien | Where-Object { $_.Passt -and $_.Zahl.Text -match ',' })
    if ($stuecke.Count -eq 0) { return $ergebnisse }
    foreach ($s in @(Get-A4WRaumstempel $items)) {
        $ngfItem = $s.Felder['NGF'].Wert; $ruItem = $s.Felder['RU'].Wert
        if (-not $ngfItem -or -not $ruItem) { continue }
        $fl = 0.0; $um = 0.0
        [void][double]::TryParse(($ngfItem.T -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$fl)
        [void][double]::TryParse(($ruItem.T -replace ',', '.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$um)
        if ($fl -le 0 -or $um -le 0) { continue }
        $raum = if ($s.NameText) { $s.NameText } elseif ($s.Nummer) { "Nr. $($s.Nummer.T)" } else { '(ohne Namen)' }
        $sx = $s.AnkerX + 15; $sy = $s.Oben + 20
        $senk = @($stuecke | Where-Object { $_.Richtung -eq 'v' -and $_.Stueck.A -le $sy -and $_.Stueck.B -ge $sy -and [math]::Abs($_.Stueck.Q - $sx) -le 250 } | Sort-Object { [math]::Abs($_.Stueck.Q - $sx) } | Select-Object -First 3)
        $waag = @($stuecke | Where-Object { $_.Richtung -eq 'h' -and $_.Stueck.A -le $sx -and $_.Stueck.B -ge $sx -and [math]::Abs($_.Stueck.Q - $sy) -le 250 } | Sort-Object { [math]::Abs($_.Stueck.Q - $sy) } | Select-Object -First 3)
        $beste = $null
        foreach ($p1 in $senk) {
            foreach ($p2 in $waag) {
                $w = $p1.Zahl.Wert; $q = $p2.Zahl.Wert
                $e = [math]::Max([math]::Abs($w * $q - $fl) / $fl, [math]::Abs(2 * ($w + $q) - $um) / $um)
                if ($null -eq $beste -or $e -lt $beste.Fehler) { $beste = [pscustomobject]@{ Fehler = $e; Text = "$($p1.Zahl.Text) mal $($p2.Zahl.Text) m" } }
            }
        }
        foreach ($p1 in @($senk + $waag)) {
            $d = $p1.Zahl.Wert; $andere = $um / 2 - $d
            if ($andere -le 0) { continue }
            $e = [math]::Abs($d * $andere - $fl) / $fl
            if ($null -eq $beste -or $e -lt $beste.Fehler) { $beste = [pscustomobject]@{ Fehler = $e; Text = "$($p1.Zahl.Text) m (andere Seite aus RU: $($andere.ToString('0.00', $de)) m)" } }
        }
        if ($null -eq $beste -or $beste.Fehler -gt 0.15) { continue }
        $prozent = ($beste.Fehler * 100).ToString('0.0', $de)
        if ($beste.Fehler -le 0.03) {
            $ergebnisse.Add((New-Result "Raum $raum (Wandmaße)" $true "NGF und RU passen zu den Wandmaßen ($($beste.Text), Abweichung $prozent %)" '' $ngfItem.X $ngfItem.Y))
        } else {
            $r = New-Result "Raum $raum (Wandmaße)" $false "NGF $($ngfItem.T) m², RU $($ruItem.T) m; Wandmaße $($beste.Text)" "Hinweis: Fläche oder Umfang von '$raum' weicht um $prozent % von den Wandmaßen ab ($($beste.Text)). Bitte NGF, RU und die Maßketten prüfen (bei nicht rechteckigen Räumen kann das stimmen)." $ngfItem.X $ngfItem.Y
            $r.Quelle = 'hinweis'
            $ergebnisse.Add($r)
        }
    }
    $ergebnisse
}
$script:Pruefungen += @{
    Id     = 'A5'
    Name   = 'Flächenplausibilität'
    Phasen = @('werk')
    Run    = { param($items, $pdfPfad) $l = @(); if ($pdfPfad -and (Test-Path $pdfPfad)) { $l = @(Get-PdfLinienCached $pdfPfad) }; @(Get-A5Flaechen $items $l) + @(Get-A5Wandmasse $items $l) }
}
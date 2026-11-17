<#
  Testlauf für die Grundriss-Prüfung: prüft alle Pläne in testplaene\entwurf und testplaene\werk
  und vergleicht das Ergebnis mit der Erwartung, die im Dateinamen steht.

  Dateinamen (siehe testplaene\LIESMICH.md):
    01_A_ok.pdf          sauberer Plan: es darf KEIN Prüfpunkt einen Befund melden
    01_A4_fehler.pdf     Plan mit Fehler bei Prüfpunkt A4: A4 muss einen Befund melden,
                         alle anderen Prüfpunkte müssen ruhig bleiben

  Aufruf aus dem Projektordner:
    powershell -File pruefung\testlauf.ps1
#>
. "$PSScriptRoot\pruefungen.ps1"

$ordner = Join-Path $PSScriptRoot '..\testplaene'

# Bekannte Zusatzfehler: Pläne, in denen absichtlich oder versehentlich mehr als der Namensfehler fehlt.
# Befunde dieser Prüfpunkte zählen dort nicht als falscher Alarm.
$bekannteZusatzfehler = @{
    # In diesem Plan fehlt auch die Höhenangabe ±0,00 (Versehen, siehe testplaene\LIESMICH.md).
    # A7 (Höhenangaben) ist gebaut: dieser Plan ist zugleich der Fehlerfall für A7 (siehe Selbsttest A7).
    '01_A4_fehler' = @('A7')
}
$richtig = 0; $falsch = 0; $uebersprungen = 0
$zeilen = New-Object System.Collections.Generic.List[string]

foreach ($phase in 'entwurf', 'werk') {
    $phasenOrdner = Join-Path $ordner $phase
    if (-not (Test-Path $phasenOrdner)) { continue }
    $aktiv = @($script:Pruefungen | Where-Object { $_.Phasen -contains $phase -and -not $_.Ki } | ForEach-Object { $_.Id })
    $zeilen.Add("")
    $zeilen.Add("== Phase: $phase   (aktive Prüfpunkte: $(if ($aktiv.Count) { $aktiv -join ', ' } else { 'keine' }))")

    foreach ($f in Get-ChildItem $phasenOrdner -Filter *.pdf | Sort-Object Name) {
        if ($f.BaseName -notmatch '^\d+_(?<punkt>A\d*[A-Z]?|Werkplanung)_(?<art>ok|fehler)') {
            $uebersprungen++
            $zeilen.Add("[übersprungen] $($f.Name)  (Name passt nicht zum Schema <nr>_<A4>_<ok|fehler>)")
            continue
        }
        $punkt = $Matches['punkt']; $art = $Matches['art']
        if ($punkt -eq 'Werkplanung') { $punkt = 'A' }   # "01_Werkplanung_ok.pdf" = sauberer Werkplan, wie "01_A_ok.pdf"

        if ($art -eq 'fehler' -and @($script:Pruefungen | Where-Object { $_.Id -eq $punkt -and $_.Ki }).Count -gt 0) {
            $uebersprungen++
            $zeilen.Add("[übersprungen] $($f.Name)  (Prüfpunkt $punkt braucht die KI und wird im Testlauf nicht mit einem echten Aufruf geprüft, siehe LIESMICH)")
            continue
        }
        if ($art -eq 'fehler' -and $aktiv -notcontains $punkt) {
            $uebersprungen++
            $zeilen.Add("[übersprungen] $($f.Name)  (Prüfpunkt $punkt ist in der Phase '$phase' noch nicht gebaut)")
            continue
        }

        $res = @(Invoke-Pruefungen $f.FullName $phase)
        $befunde = @($res | Where-Object { -not $_.Ok })
        $gutePunkte = @($res | Where-Object { $_.Ok }).Count

        if ($art -eq 'ok') {
            if ($befunde.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      $($f.Name)  ($gutePunkte Angaben in Ordnung, keine Befunde)") }
            else {
                $falsch++
                $zeilen.Add("[FALSCH]       $($f.Name)  falscher Alarm bei einem sauberen Plan:")
                foreach ($b in $befunde) { $zeilen.Add("                  [$($b.Punkt)] $($b.Angabe): $($b.Detail)") }
            }
        } else {
            $imPunkt = @($befunde | Where-Object { $_.Punkt -eq $punkt })
            $erlaubt = @($bekannteZusatzfehler[$f.BaseName])
            $andere = @($befunde | Where-Object { $_.Punkt -ne $punkt -and $erlaubt -notcontains $_.Punkt })
            if ($imPunkt.Count -gt 0 -and $andere.Count -eq 0) {
                $richtig++
                $zeilen.Add("[richtig]      $($f.Name)  ($($imPunkt.Count) Befund(e) bei $punkt gefunden)")
            } else {
                $falsch++
                $zeilen.Add("[FALSCH]       $($f.Name)")
                if ($imPunkt.Count -eq 0) { $zeilen.Add("                  übersehen: bei $punkt wurde kein Befund gemeldet") }
                foreach ($b in $andere) { $zeilen.Add("                  falscher Alarm: [$($b.Punkt)] $($b.Angabe): $($b.Detail)") }
            }
        }
    }
}

# Selbsttest A4: Die Fläche darf auch ohne "NGF:" im Stempel stehen (nur die Zahl mit m²).
# Wir nehmen den sauberen Plan, löschen alle "NGF:"-Beschriftungen und prüfen, dass weiter alle Räume erkannt werden.
$okPlan = Get-ChildItem (Join-Path $ordner 'entwurf') -Filter '*_A_ok.pdf' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($okPlan -and (Get-AktivePruefungen 'entwurf') -contains 'A4 Raumflächen') {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A4: Fläche ohne 'NGF:'")
    $alle = @(Get-PdfTextItems $okPlan.FullName)
    $ohne = @($alle | Where-Object { $_.T -notmatch '^NGF\s*:?$' })
    $vorher = @(Get-A4Raumflaechen $alle | Where-Object { $_.Ok }).Count
    $nachher = @(Get-A4Raumflaechen $ohne)
    $nachherOk = @($nachher | Where-Object { $_.Ok }).Count
    $nachherBefunde = @($nachher | Where-Object { -not $_.Ok }).Count
    if ($vorher -gt 0 -and $nachherOk -eq $vorher -and $nachherBefunde -eq 0) {
        $richtig++
        $zeilen.Add("[richtig]      alle $nachherOk Räume werden auch ohne 'NGF:' erkannt")
    } else {
        $falsch++
        $zeilen.Add("[FALSCH]       mit 'NGF:' $vorher Räume in Ordnung, ohne 'NGF:' $nachherOk in Ordnung und $nachherBefunde Befunde")
    }

    # Nur beim Flur die Fläche entfernen: genau ein Befund beim Flur muss kommen
    $flur = $alle | Where-Object { $_.T -eq 'Flur' } | Select-Object -First 1
    if ($flur) {
        $ohneFlur = @($alle | Where-Object { -not ($_.Y -gt $flur.Y + 5 -and $_.Y -lt $flur.Y + 30 -and [math]::Abs($_.X - $flur.X) -lt 50) })
        $b = @(Get-A4Raumflaechen $ohneFlur | Where-Object { -not $_.Ok })
        if ($b.Count -eq 1 -and $b[0].Angabe -eq 'Raum Flur') { $richtig++; $zeilen.Add("[richtig]      fehlt nur beim Flur die Fläche, wird genau der Flur gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Fläche nur beim Flur entfernt: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Angabe }) -join ', '))") }

        # Fläche 0,00 beim Flur: muss als Befund kommen
        $zero = @($alle | ForEach-Object { if ($_.T -match '^\d{1,2},\d{2}$' -and [math]::Abs($_.Y - $flur.Y) -lt 20 -and [math]::Abs($_.X - $flur.X) -lt 40) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = '0,00' } } else { $_ } })
        $b = @(Get-A4Raumflaechen $zero | Where-Object { -not $_.Ok })
        if ($b.Count -eq 1 -and $b[0].Angabe -eq 'Raum Flur') { $richtig++; $zeilen.Add("[richtig]      Fläche 0,00 beim Flur wird als Befund gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Fläche 0,00 beim Flur: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Angabe }) -join ', '))") }
    }
}

# Selbsttest A7: Höhenkote in verschiedenen Schreibweisen erkannt, und der Plan 01_A4_fehler (ohne ±0,00) wird gemeldet.
if (@($script:Pruefungen | Where-Object { $_.Id -eq 'A7' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A7: Höhenangaben")
    $schreibweisen = '±0,00', '+0,00', '-0,15', '+ 2,76', '±0.00', 'OKFF +2,76', 'OKFF 2,76', 'OK FFB -0,03'
    $fehlerSchreibweisen = @()
    foreach ($s in $schreibweisen) {
        $r = Get-A7Hoehenangaben @([pscustomobject]@{ X = 1; Y = 1; T = $s })
        if (-not $r.Ok) { $fehlerSchreibweisen += $s }
    }
    if ($fehlerSchreibweisen.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      $($schreibweisen.Count) Schreibweisen einer Höhenkote werden erkannt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       nicht erkannt: $($fehlerSchreibweisen -join ' | ')") }

    # Zahlen, die keine Höhenkote sind, dürfen nicht zählen (Maßzahlen, Flächen, Datum, Plannummer)
    $keine = '1,49', '22,50', '16.11.2026', '1:100', 'G01', '12345', '2,51', 'NGF:'
    $zuviel = @($keine | Where-Object { (Get-A7Hoehenangaben @([pscustomobject]@{ X = 1; Y = 1; T = $_ })).Ok })
    if ($zuviel.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Maßzahlen, Flächen und Datum werden nicht als Höhenkote gezählt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       fälschlich als Höhenkote erkannt: $($zuviel -join ' | ')") }

    $fehlerPlan = Join-Path $ordner 'entwurf\01_A4_fehler.pdf'
    if (Test-Path $fehlerPlan) {
        $r = @(Invoke-Pruefungen $fehlerPlan 'entwurf' | Where-Object { $_.Punkt -eq 'A7' -and -not $_.Ok })
        if ($r.Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      01_A4_fehler.pdf: die fehlende Höhenangabe ±0,00 wird als A7-Befund gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       01_A4_fehler.pdf: $($r.Count) A7-Befunde statt 1") }
    }
}

# Selbsttest A1: Nordpfeil (Buchstabe N)
if ($okPlan -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A1' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A1: Nordpfeil")
    $itemsA1 = @(Get-PdfTextItems $okPlan.FullName)
    $r = Get-A1Nordpfeil $itemsA1
    if ($r.Ok) { $richtig++; $zeilen.Add("[richtig]      Musterplan: Nordpfeil erkannt ($($r.Wert))") } else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: Nordpfeil nicht erkannt") }
    $ohneN = @($itemsA1 | Where-Object { $_.T -cne 'N' })
    $r = Get-A1Nordpfeil $ohneN
    if (-not $r.Ok -and $r.Detail -match 'kein Nordpfeil') { $richtig++; $zeilen.Add("[richtig]      ohne das N wird 'kein Nordpfeil' gemeldet") } else { $falsch++; $zeilen.Add("[FALSCH]       ohne N: Ok=$($r.Ok)") }
    $nurWoerter = @([pscustomobject]@{ X = 1; Y = 1; T = 'NGF:' }, [pscustomobject]@{ X = 1; Y = 2; T = 'Nord' }, [pscustomobject]@{ X = 1; Y = 3; T = 'n' })
    $r = Get-A1Nordpfeil $nurWoerter
    if (-not $r.Ok) { $richtig++; $zeilen.Add("[richtig]      'NGF:', 'Nord' und kleines 'n' zählen nicht als Nordpfeil") } else { $falsch++; $zeilen.Add("[FALSCH]       Wörter wurden als Nordpfeil gezählt") }
}

# Selbsttest A6: Schnittlinien (Dreiecke aus der PDF-Geometrie, Buchstaben aus dem Text)
if ($okPlan -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A6' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A6: Schnittlinien")
    $itemsA6 = @(Get-PdfTextItems $okPlan.FullName)
    $dreieckeA6 = @(Get-PdfDreiecke $okPlan.FullName)
    $grosse = @($dreieckeA6 | Where-Object { $_.Kante -ge 8 } | Sort-Object { $_.Mitte.Y })

    if ($grosse.Count -eq 2 -and $grosse[0].Richtung -eq 'links' -and $grosse[1].Richtung -eq 'links' -and [math]::Abs($grosse[0].Mitte.Y - 110.6) -lt 2 -and [math]::Abs($grosse[1].Mitte.Y - 513.6) -lt 2) { $richtig++; $zeilen.Add("[richtig]      Musterplan: zwei Schnitt-Dreiecke bei den Buchstaben A, beide zeigen nach links") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Dreiecke im Musterplan: $(($grosse | ForEach-Object { "($([math]::Round($_.Mitte.X)),$([math]::Round($_.Mitte.Y))) $($_.Richtung)" }) -join '; ')") }

    $r = @(Get-A6Pruefung $itemsA6 $dreieckeA6)
    if (@($r | Where-Object { $_.Ok -and $_.Angabe -eq 'Schnitt A' }).Count -eq 1 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Musterplan: Schnitt A in Ordnung, keine Befunde") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok)" }) -join ', ')") }

    if ($grosse.Count -eq 2) {
        $r = @(Get-A6Pruefung $itemsA6 @($dreieckeA6 | Where-Object { $_ -ne $grosse[1] }) | Where-Object { -not $_.Ok })
        if ($r.Count -eq 1 -and $r[0].Detail -match 'fehlt an einem Ende das Dreieck') { $richtig++; $zeilen.Add("[richtig]      fehlt ein Dreieck: 'an einem Ende fehlt das Dreieck'") }
        else { $falsch++; $zeilen.Add("[FALSCH]       ein Dreieck entfernt: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Detail }) -join ' | '))") }

        $r = @(Get-A6Pruefung $itemsA6 @($dreieckeA6 | Where-Object { $_ -ne $grosse[0] -and $_ -ne $grosse[1] }) | Where-Object { -not $_.Ok })
        if ($r.Count -eq 1 -and $r[0].Angabe -eq 'Schnittlinie') { $richtig++; $zeilen.Add("[richtig]      fehlen beide Dreiecke (Buchstaben bleiben): 'keine Schnittlinie gefunden', Buchstaben allein zählen nicht") }
        else { $falsch++; $zeilen.Add("[FALSCH]       beide Dreiecke entfernt: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Detail }) -join ' | '))") }

        $gedreht = [pscustomobject]@{ P1 = $grosse[1].P1; P2 = $grosse[1].P2; P3 = $grosse[1].P3; Mitte = $grosse[1].Mitte; Kante = $grosse[1].Kante; Richtung = 'rechts' }
        $r = @(Get-A6Pruefung $itemsA6 @(@($dreieckeA6 | Where-Object { $_ -ne $grosse[1] }) + $gedreht) | Where-Object { -not $_.Ok })
        if ($r.Count -eq 1 -and $r[0].Detail -match 'unterschiedliche Richtungen \(links und rechts\)') { $richtig++; $zeilen.Add("[richtig]      Dreiecke in verschiedene Richtungen: wird gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Richtung gedreht: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Detail }) -join ' | '))") }
    }

    $ohneBuchstaben = @($itemsA6 | Where-Object { $_.T -cne 'A' })
    $r = @(Get-A6Pruefung $ohneBuchstaben $dreieckeA6)
    if (@($r | Where-Object { -not $_.Ok }).Count -eq 0 -and @($r | Where-Object { $_.Ok -and $_.Wert -match 'ohne Buchstaben' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Schnittlinie ohne Buchstaben (nur Dreiecke) ist in Ordnung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Buchstaben: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok) $($_.Detail)" }) -join ' | ')") }

    $enden = @($itemsA6 | Where-Object { $_.T -ceq 'A' } | Sort-Object Y)
    if ($enden.Count -eq 2) {
        $r = @(Get-A6Pruefung @($itemsA6 | Where-Object { $_ -ne $enden[1] }) $dreieckeA6 | Where-Object { -not $_.Ok })
        if ($r.Count -eq 1 -and $r[0].Detail -match 'nur an einem Ende beschriftet') { $richtig++; $zeilen.Add("[richtig]      nur ein Buchstabe bei beiden Dreiecken: 'nur an einem Ende beschriftet'") }
        else { $falsch++; $zeilen.Add("[FALSCH]       ein Buchstabe entfernt: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Detail }) -join ' | '))") }
    }

    $r = @(Get-A6Pruefung $ohneBuchstaben @() | Where-Object { -not $_.Ok })
    $nurN = @([pscustomobject]@{ X = 1000; Y = 60; T = 'N' })
    $r2 = @(Get-A6Pruefung $nurN @() | Where-Object { -not $_.Ok })
    $kleine = @($dreieckeA6 | Where-Object { $_.Kante -lt 8 })
    $r3 = @(Get-A6Pruefung @() $kleine | Where-Object { -not $_.Ok })
    if ($r.Count -eq 1 -and $r[0].Angabe -eq 'Schnittlinie' -and $r2.Count -eq 1 -and $r2[0].Angabe -eq 'Schnittlinie' -and $r3.Count -eq 1 -and $r3[0].Angabe -eq 'Schnittlinie') { $richtig++; $zeilen.Add("[richtig]      ohne Dreiecke und Buchstaben, nur N, nur kleine Dreiecke: 'keine Schnittlinie gefunden'") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Keine-Schnittlinie-Fälle: $($r.Count), $($r2.Count), $($r3.Count)") }

    # Schraffur: viele große Dreiecke dicht beieinander sind keine Schnitt-Dreiecke, auch wenn zwei davon weit auseinander paarig lägen
    function Neues-Dreieck($x, $y) { [pscustomobject]@{ P1 = [pscustomobject]@{ X = $x; Y = $y }; P2 = [pscustomobject]@{ X = $x; Y = $y + 12 }; P3 = [pscustomobject]@{ X = $x - 12; Y = $y + 6 }; Mitte = [pscustomobject]@{ X = $x - 4; Y = $y + 6 }; Kante = 13.4; Richtung = 'links' } }
    $hatch = @((Neues-Dreieck 250 205), (Neues-Dreieck 260 214), (Neues-Dreieck 247 220), (Neues-Dreieck 250 940), (Neues-Dreieck 260 949), (Neues-Dreieck 247 955))
    $rh = @(Get-A6Pruefung @() $hatch | Where-Object { -not $_.Ok })
    $einzel = @((Neues-Dreieck 600 170), (Neues-Dreieck 600 1010))
    $re = @(Get-A6Pruefung @() $einzel)
    if ($rh.Count -eq 1 -and $rh[0].Angabe -eq 'Schnittlinie' -and @($re | Where-Object { $_.Ok }).Count -eq 1 -and @($re | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Dreiecke in Schraffuren werden ignoriert, zwei einzelne weit entfernte Dreiecke sind eine Schnittlinie") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Schraffur-Test: Schraffur=$($rh.Count) Befunde, einzeln ok=$(@($re | Where-Object { $_.Ok }).Count)") }

    $dicht = @([pscustomobject]@{ X = 100; Y = 100; T = 'B' }, [pscustomobject]@{ X = 100; Y = 150; T = 'B' })
    $r4 = @(Get-A6Pruefung $dicht @() | Where-Object { -not $_.Ok })
    $waagrecht = @([pscustomobject]@{ X = 100; Y = 300; T = 'C' }, [pscustomobject]@{ X = 600; Y = 303; T = 'C' })
    $r5 = @(Get-A6Pruefung $waagrecht @() | Where-Object { -not $_.Ok })
    if ($r4.Count -eq 1 -and $r4[0].Angabe -eq 'Schnittlinie' -and $r5.Count -eq 1 -and $r5[0].Angabe -eq 'Schnittlinie') { $richtig++; $zeilen.Add("[richtig]      gleiche Buchstaben allein (zum Beispiel Achsbezeichnungen) sind keine Schnittlinie") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Sonderfälle: dicht=$($r4.Count), waagrecht=$($r5.Count)") }
}
# Selbsttest A3: Fehlt nur beim Flur der Raumname, muss genau ein Befund (zur Fläche des Flurs) kommen.
if ($okPlan -and (Get-AktivePruefungen 'entwurf') -contains 'A3 Raumbezeichnungen') {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A3: Raumname fehlt nur beim Flur")
    $alleA3 = @(Get-PdfTextItems $okPlan.FullName)
    $flurA3 = $alleA3 | Where-Object { $_.T -eq 'Flur' } | Select-Object -First 1
    if ($flurA3) {
        $ohneName = @($alleA3 | Where-Object { $_ -ne $flurA3 })
        $b = @(Get-A3Raumbezeichnungen $ohneName)
        if ($b.Count -eq 1 -and $b[0].Wert -eq '22,50 m²') { $richtig++; $zeilen.Add("[richtig]      genau 1 Befund, zur Fläche 22,50 m² des Flurs") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Raumname nur beim Flur entfernt: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Angabe }) -join ', '))") }
    }
}

# Selbsttest A4W: Werk-Raumstempel (Fehler werden im Speicher nachgestellt: Textstücke aus dem sauberen Werkplan ändern)
# Regel vom Team: fehlende erweiterte Angaben (Nummer, RU, RH, FB, WB, DB) sind KEIN Fehler. Geprüft werden nur
# vorhandene Raumnummern (doppelt, Lücke) und die Raumhöhe. Raumname und Fläche prüfen A3 und A4.
$werkOk = Get-ChildItem (Join-Path $ordner 'werk') -Filter '*_Werkplanung_ok.pdf' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A4W' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A4W: Werk-Raumstempel")
    $itemsW = @(Get-PdfTextItems $werkOk.FullName)
    $stempelW = @(Get-A4WRaumstempel $itemsW)
    $r = @(Get-A4WWerkRaumstempel $itemsW)
    if ($stempelW.Count -eq 7 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Musterplan: 7 Stempel erkannt (Treppenholm ist kein Raum), keine Befunde") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $($stempelW.Count) Stempel, $(@($r | Where-Object { -not $_.Ok }).Count) Befunde") }

    $buero = $stempelW | Where-Object { $_.NameText -eq 'Büro' } | Select-Object -First 1
    $flurS = $stempelW | Where-Object { $_.NameText -eq 'Flur' } | Select-Object -First 1
    if ($buero -and $flurS) {
        # Fehlende erweiterte Angaben sind kein Fehler: je Feld die Zeile (Beschriftung und Wert) beim Büro entfernen
        $schlecht = @()
        foreach ($f in $script:A4wFelder) {
            $d = $buero.Felder[$f.Label]
            $b = @(Get-A4WWerkRaumstempel @($itemsW | Where-Object { $_ -ne $d.Wert -and $_ -ne $d.Label }) | Where-Object { -not $_.Ok })
            if ($b.Count -ne 0) { $schlecht += $f.Label }
        }
        if ($schlecht.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      fehlt beim Büro NGF, RU, RH, FB, WB oder DB (je einzeln): kein Befund von A4W") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Befund trotz fehlender erweiterter Angabe bei: $($schlecht -join ', ')") }

        # Alle erweiterten Angaben von allen Räumen weg (nur Name, Nummer, Fläche bleiben): kein Befund
        $nurBasis = @($itemsW | Where-Object { $it = $_; -not (@($stempelW | ForEach-Object { foreach ($l in 'RU', 'RH', 'FB', 'WB', 'DB') { $_.Felder[$l].Label; $_.Felder[$l].Wert } }) -contains $it) })
        $b = @(Get-A4WWerkRaumstempel $nurBasis | Where-Object { -not $_.Ok })
        if ($b.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Stempel nur mit Name, Nummer und Fläche: kein Befund") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Basisstempel: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }

        # Gar keine Raumnummern: kein Befund
        $ohneNr = @($itemsW | Where-Object { $it = $_; -not (@($stempelW | ForEach-Object { $_.Nummer }) -contains $it) })
        $b = @(Get-A4WWerkRaumstempel $ohneNr | Where-Object { -not $_.Ok })
        if ($b.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      keine Raumnummern im Plan: kein Befund") }
        else { $falsch++; $zeilen.Add("[FALSCH]       ohne Raumnummern: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }

        # Doppelte Nummer: Büro (02) bekommt die Nummer vom Flur (01) -> beide gemeldet
        $doppelt = @($itemsW | ForEach-Object { if ($_ -eq $buero.Nummer) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = $flurS.Nummer.T } } else { $_ } })
        $b = @(Get-A4WWerkRaumstempel $doppelt | Where-Object { -not $_.Ok })
        if (@($b | Where-Object { $_.Detail -match 'mehrfach' }).Count -eq 2 -and @($b | Where-Object { $_.Angabe -eq 'Raum Büro' -and $_.Detail -match 'mehrfach' }).Count -eq 1 -and @($b | Where-Object { $_.Detail -match 'lückenlos' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      doppelte Raumnummer: beide Räume gemeldet, dazu die entstandene Lücke") }
        else { $falsch++; $zeilen.Add("[FALSCH]       doppelte Nummer: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }

        # Lücke: Nummer 05 (HWR) wird 09 -> Lücke 05 bis 08 ... Befund 'nicht lückenlos'
        $hwr = $stempelW | Where-Object { $_.NameText -eq 'HWR' } | Select-Object -First 1
        $luecke = @($itemsW | ForEach-Object { if ($_ -eq $hwr.Nummer) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = '09' } } else { $_ } })
        $b = @(Get-A4WWerkRaumstempel $luecke | Where-Object { -not $_.Ok })
        if ($b.Count -eq 1 -and $b[0].Detail -match 'lückenlos' -and $b[0].Detail -match '05, 08') { $richtig++; $zeilen.Add("[richtig]      Lücke in den Raumnummern wird gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Lücke: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }

        # Eine Nummer fehlt, andere sind da: gemeldet. Die Lücke in der Reihenfolge wird mit gemeldet (02 fehlt)
        $b = @(Get-A4WWerkRaumstempel @($itemsW | Where-Object { $_ -ne $buero.Nummer }) | Where-Object { -not $_.Ok })
        if (@($b | Where-Object { $_.Angabe -eq 'Raum Büro' -and $_.Detail -match 'Raumnummer fehlt' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Nummer nur beim Büro entfernt (andere haben eine): wird gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Nummer beim Büro entfernt: $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }

        # Raumhöhe: 26,50 statt 2,650 und 1,00 wird gemeldet, 2,40 und 3,00 sind in Ordnung
        foreach ($fall in @(@('26,50', $true), @('1,00', $true), @('2,40', $false), @('3,00', $false))) {
            $rhItem = $buero.Felder['RH'].Wert
            $x = @($itemsW | ForEach-Object { if ($_ -eq $rhItem) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = $fall[0] } } else { $_ } })
            $b = @(Get-A4WWerkRaumstempel $x | Where-Object { -not $_.Ok })
            $gut = if ($fall[1]) { $b.Count -eq 1 -and $b[0].Detail -match 'Raumhöhe' -and $null -ne $b[0].X } else { $b.Count -eq 0 }
            if ($gut) { $richtig++; $zeilen.Add("[richtig]      Raumhöhe $($fall[0]) m: $(if ($fall[1]) { 'wird gemeldet' } else { 'in Ordnung' })") }
            else { $falsch++; $zeilen.Add("[FALSCH]       Raumhöhe $($fall[0]): $($b.Count) Befunde") }
        }

        # Zusammenspiel in der Werkphase: Ohne Fläche (NGF-Zeile) meldet A4, ohne Raumname meldet A3
        $ohneNgf = @($itemsW | Where-Object { $_ -ne $buero.Felder['NGF'].Label -and $_ -ne $buero.Felder['NGF'].Wert })
        $b = @(Get-A4Raumflaechen $ohneNgf | Where-Object { -not $_.Ok })
        if (@($b | Where-Object { $_.Angabe -eq 'Raum Büro' }).Count -ge 1) { $richtig++; $zeilen.Add("[richtig]      Büro ohne Fläche (NGF-Zeile weg): A4 meldet es") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Büro ohne NGF: A4 meldet $($b.Count) Befunde") }
        $ohneName = @($itemsW | Where-Object { $_ -ne $buero.Name })
        $b = @(Get-A3Raumbezeichnungen $ohneName | Where-Object { -not $_.Ok })
        if ($b.Count -ge 1) { $richtig++; $zeilen.Add("[richtig]      Raumstempel ohne Raumname: A3 meldet es") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Büro ohne Namen: A3 meldet nichts") }

        if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A4W*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A4W läuft nur in der Werkplanung, nicht im Entwurf") }
        else { $falsch++; $zeilen.Add("[FALSCH]       A4W ist auch im Entwurf aktiv") }
    }
}
# Selbsttest A10: BRH je Fenster (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A10' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A10: BRH je Fenster")
    $itemsB = @(Get-PdfTextItems $werkOk.FullName)
    $brhB = @($itemsB | Where-Object { $_.T -cmatch '^BRH' })
    $r = @(Get-A10Brh $itemsB)
    if ($brhB.Count -eq 14 -and $r.Count -eq 14 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Musterplan: 14 BRH-Angaben, alle mit Wert") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $($brhB.Count) BRH gefunden, $($r.Count) Ergebnisse, $(@($r | Where-Object { -not $_.Ok }).Count) Befunde") }

    # Wert hinter der ersten BRH entfernen (BRH 0,00 im unteren Plan): genau ein Befund an dieser Stelle
    $erste = $brhB | Sort-Object Y, X | Select-Object -First 1
    $wertE = $itemsB | Where-Object { [math]::Abs($_.Y - $erste.Y) -le 2.5 -and $_.X -gt $erste.X + 3 -and ($_.X - $erste.X) -le 45 -and $_.T -match $script:BrhWert } | Select-Object -First 1
    $b = @(Get-A10Brh @($itemsB | Where-Object { $_ -ne $wertE }) | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and [math]::Abs($b[0].X - $erste.X) -lt 1 -and [math]::Abs($b[0].Y - $erste.Y) -lt 1) { $richtig++; $zeilen.Add("[richtig]      Wert hinter einer BRH fehlt: genau ein Befund an dieser Stelle (Position)") }
    else { $falsch++; $zeilen.Add("[FALSCH]       BRH-Wert entfernt: $($b.Count) Befunde") }

    # Wert steht bei einer BRH, die an anderer Stelle (nicht auf derselben Zeile) liegt: zählt nicht
    $versetzt = @($itemsB | ForEach-Object { if ($_ -eq $wertE) { [pscustomobject]@{ X = $_.X; Y = $_.Y + 30; T = $_.T } } else { $_ } })
    $b = @(Get-A10Brh $versetzt | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Wert auf anderer Zeile zählt nicht als Wert der BRH") }
    else { $falsch++; $zeilen.Add("[FALSCH]       versetzter BRH-Wert: $($b.Count) Befunde") }

    # Keine BRH im Plan: Befund
    $b = @(Get-A10Brh @($itemsB | Where-Object { $_.T -cnotmatch '^BRH' }) | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and $b[0].Detail -match 'keine BRH') { $richtig++; $zeilen.Add("[richtig]      keine BRH im Plan: ein Befund") }
    else { $falsch++; $zeilen.Add("[FALSCH]       keine BRH: $($b.Count) Befunde") }

    # BRH und Wert in einem Stück ("BRH 95"), "BRH:" und Wörter wie BRHxyz
    $einStueck = @([pscustomobject]@{ X = 10; Y = 10; T = 'BRH 95' }, [pscustomobject]@{ X = 50; Y = 50; T = 'BRH: 0,00' }, [pscustomobject]@{ X = 90; Y = 90; T = 'BRH' }, [pscustomobject]@{ X = 100; Y = 90.5; T = '1,01' })
    $r = @(Get-A10Brh $einStueck)
    if ($r.Count -eq 3 -and @($r | Where-Object { $_.Ok }).Count -eq 3) { $richtig++; $zeilen.Add("[richtig]      'BRH 95', 'BRH: 0,00' und BRH mit Wert als eigenes Stück werden erkannt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Schreibweisen: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok)" }) -join ', ')") }

    $ohneWert = @([pscustomobject]@{ X = 10; Y = 10; T = 'BRH' }, [pscustomobject]@{ X = 20; Y = 10; T = 'Fenster' })
    $b = @(Get-A10Brh $ohneWert | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and $b[0].Detail -match 'keinen Wert') { $richtig++; $zeilen.Add("[richtig]      BRH ohne Zahl dahinter wird gemeldet") }
    else { $falsch++; $zeilen.Add("[FALSCH]       BRH ohne Zahl: $($b.Count) Befunde") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A10*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A10 läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A10 ist auch im Entwurf aktiv") }
}
# Selbsttest KI-Anbindung: ohne echten Aufruf (die KI wird hier nur nachgestellt, es wird nichts gesendet).
if ($okPlan -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A3K' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest KI (A3K), ohne echten Aufruf")
    $anzahlKi = @($script:Pruefungen | Where-Object { $_.Ki -and $_.Phasen -contains 'entwurf' }).Count

    # Schlüsseldatei lesen (nur Textzeilen, mit erfundenen Werten, kein echter Schlüssel)
    $fakeKey = 'AIzaTESTWERT123'
    $faelle = @(
        @{ Name = 'Platzhalter zählt nicht';       Zeilen = @('# Kommentar', 'HIER-DEN-SCHLUESSEL-EINFUEGEN'); Soll = $null },
        @{ Name = 'nur der Schlüssel';             Zeilen = @('# Kommentar', '', $fakeKey);                    Soll = $fakeKey },
        @{ Name = 'GEMINI_API_KEY=...';            Zeilen = @("GEMINI_API_KEY=$fakeKey");                      Soll = $fakeKey },
        @{ Name = 'mit Anführungszeichen und Leerzeichen'; Zeilen = @("  GEMINI_API_KEY = `"$fakeKey`"  "); Soll = $fakeKey },
        @{ Name = 'Platzhalter hinter KEY=';       Zeilen = @('GEMINI_API_KEY=HIER-DEN-SCHLUESSEL-EINFUEGEN'); Soll = $null },
        @{ Name = 'nur modell=... ist kein Schlüssel'; Zeilen = @('modell=gemini-3.5-flash-lite');            Soll = $null }
    )
    $schlechte = @($faelle | Where-Object { (Get-KiSchluesselAusZeilen $_.Zeilen) -ne $_.Soll } | ForEach-Object { $_.Name })
    if ($schlechte.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Schlüsseldatei: alle $($faelle.Count) Schreibweisen werden richtig gelesen") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Schlüsseldatei falsch gelesen bei: $($schlechte -join ' | ')") }

    # 1. Antwort der KI wird richtig in Befunde umgewandelt
    $antwort = '{"weitere_raeume":[{"lage":"links oben, neben dem Flur","x_prozent":12.4,"y_prozent":30}]}' | ConvertFrom-Json
    $e = @(ConvertTo-A3KErgebnisse $antwort)
    if ($e.Count -eq 1 -and -not $e[0].Ok -and $e[0].Quelle -eq 'ki' -and $e[0].Detail -match 'links oben' -and $e[0].Detail -match '12 %') { $richtig++; $zeilen.Add("[richtig]      KI-Antwort wird zu einem KI-Hinweis mit Lage") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI-Antwort wurde nicht richtig umgewandelt: $($e | ConvertTo-Json -Compress)") }

    # 2. Leere Liste der KI ergibt keine Befunde
    $e = @(ConvertTo-A3KErgebnisse ('{"weitere_raeume":[]}' | ConvertFrom-Json))
    if ($e.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      leere KI-Antwort ergibt keine Befunde") }
    else { $falsch++; $zeilen.Add("[FALSCH]       leere KI-Antwort ergab $($e.Count) Befunde") }

    # Ab hier wird die KI nachgestellt: kein echter Aufruf, egal ob ein Schlüssel hinterlegt ist
    function Test-KiVerfuegbar { $script:TestKiAn }
    function Invoke-KiPdfFrage { param($PdfPfad, $Frage, $Schema) $script:TestKiAufrufe++; if ($script:TestKiFehler) { throw $script:TestKiFehler }; $script:TestKiAntwort }
    $script:TestKiAufrufe = 0; $script:TestKiFehler = $null

    # 3. Ohne Schlüssel: KI-Prüfung läuft nicht, es kommt eine Meldung, der Rest funktioniert
    $script:TestKiAn = $false
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $m = @(Get-Meldungen)
    if ($script:TestKiAufrufe -eq 0 -and $m.Count -eq $anzahlKi -and $m[0] -match 'kein KI-Schlüssel' -and @($res | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      ohne Schlüssel: keine KI-Anfrage, eine verständliche Meldung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Schlüssel: Aufrufe=$($script:TestKiAufrufe), Meldungen=$($m.Count)") }

    # 4. KI nicht eingeschaltet: es wird keine Anfrage gestellt (Datenschutz)
    $script:TestKiAn = $true; $script:TestKiAufrufe = 0
    $script:TestKiAntwort = '{"weitere_raeume":[{"lage":"rechts unten"}],"bereiche":[]}' | ConvertFrom-Json
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $false)
    if ($script:TestKiAufrufe -eq 0 -and @($res | Where-Object { $_.Quelle -eq 'ki' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      KI aus: es wird nichts an die KI gesendet") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI aus, aber Aufrufe=$($script:TestKiAufrufe)") }

    # 5. KI eingeschaltet: genau eine Anfrage, der Hinweis erscheint als Befund mit Punkt A3K
    $script:TestKiAufrufe = 0
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $ki = @($res | Where-Object { $_.Quelle -eq 'ki' })
    if ($script:TestKiAufrufe -eq $anzahlKi -and $ki.Count -eq 1 -and $ki[0].Punkt -eq 'A3K') { $richtig++; $zeilen.Add("[richtig]      KI ein: je KI-Prüfpunkt eine Anfrage ($anzahlKi), KI-Hinweis als Befund A3K") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI ein: Aufrufe=$($script:TestKiAufrufe), KI-Befunde=$($ki.Count)") }

    # 5b. Falsche Struktur der KI-Antwort (wie beim ersten Live-Test): darf nicht als "keine Funde" durchgehen, sondern gibt eine Meldung
    $script:TestKiFehler = $null
    $script:TestKiAntwort = '[{"Raumname":"Flur","Flächenangabe":"22,50 m²"}]' | ConvertFrom-Json
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $m = @(Get-Meldungen)
    if ($m.Count -eq $anzahlKi -and $m[0] -match 'Struktur') { $richtig++; $zeilen.Add("[richtig]      falsche KI-Struktur: Meldung statt stillem 'keine Funde'") }
    else { $falsch++; $zeilen.Add("[FALSCH]       falsche KI-Struktur: Meldungen=$($m.Count) ($($m -join ' | '))") }
    $script:TestKiAntwort = '{"weitere_raeume":[{"lage":"rechts unten"}],"bereiche":[]}' | ConvertFrom-Json

    # 5c. Antworttext aus der Interactions-Antwort (steps) wird gelesen
    $stepsAntwort = '{"steps":[{"type":"thought","signature":"x"},{"type":"model_output","content":[{"type":"text","text":"{\"raeume\":[]}"}]}]}' | ConvertFrom-Json
    if ((Get-KiAntwortText $stepsAntwort) -eq '{"raeume":[]}') { $richtig++; $zeilen.Add("[richtig]      Interactions-Antwort (steps) wird gelesen") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Interactions-Antwort (steps) nicht gelesen") }

    # 6. Fehler der KI (zum Beispiel Limit): Meldung statt Absturz, normale Prüfungen laufen weiter
    $script:TestKiFehler = 'Das kostenlose KI-Limit ist erreicht.'
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $m = @(Get-Meldungen)
    if ($m.Count -eq $anzahlKi -and $m[0] -match 'Limit' -and @($res | Where-Object { $_.Punkt -eq 'A4' -and $_.Ok }).Count -gt 0) { $richtig++; $zeilen.Add("[richtig]      KI-Fehler: Meldung, die anderen Prüfungen laufen weiter") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI-Fehler: Meldungen=$($m.Count)") }
}

$zeilen | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host ("Ergebnis: {0} richtig, {1} falsch, {2} übersprungen (von {3} Prüfungen)" -f $richtig, $falsch, $uebersprungen, ($richtig + $falsch + $uebersprungen))

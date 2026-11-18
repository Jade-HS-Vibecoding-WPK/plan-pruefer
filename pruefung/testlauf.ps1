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
    # Die falsche Zahl 2,45 (statt 2,43) passt auch nicht zu ihrer Maßlinie: A2M meldet denselben Fehler (seit 18.11.).
    '05_A2_fehler' = @('A2M')
    # Dritter Werkplan (vom Team 18.11., vorher test_Werkplanung.pdf): ohne Nordpfeil, Höhenkote, BRH, Planbezeichnung
    # und Achsraster (vom Team bestätigt). Hat eine Raumliste mit Belägen und "Wohnung 1" bis "4" (dürfen nicht melden).
    '06_A1_fehler' = @('A7', 'A9', 'A10', 'A11')
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
        # Hinweise (Quelle "hinweis", zum Beispiel A5 Wandmaße) sind keine sicheren Fehler und zählen hier nicht als Befund
        $befunde = @($res | Where-Object { -not $_.Ok -and $_.Quelle -ne 'hinweis' })
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
# Selbsttest A11: Planinhalt beschriftet (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A11' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A11: Planinhalt beschriftet")
    $itemsC = @(Get-PdfTextItems $werkOk.FullName)
    $r = @(Get-A11Planinhalt $itemsC)
    if (@($r | Where-Object { -not $_.Ok }).Count -eq 0 -and @($r | Where-Object { $_.Angabe -eq 'Maßstab im Plankopf' -and $_.Ok }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Musterplan: Bezeichnung mit 1:50 da, Plankopf stimmt überein") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok) $($_.Detail)" }) -join ' | ')") }

    $titelC = $itemsC | Where-Object { $_.T -ceq 'GRUNDRISS' -and $_.X -lt 200 } | Select-Object -First 1
    $skalaC = $itemsC | Where-Object { $_.T -eq '1:50' -and [math]::Abs($_.Y - $titelC.Y) -le 3 } | Select-Object -First 1
    # Nur "GRUNDRISS" weg: "ERDGESCHOSS M 1:50" bleibt und gilt seit 18.11. als Bezeichnung (Geschossname, Museumsplan)
    $nurGeschoss = @(Get-A11Planinhalt @($itemsC | Where-Object { $_ -ne $titelC }) | Where-Object { -not $_.Ok })
    if ($nurGeschoss.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      nur GRUNDRISS fehlt, ERDGESCHOSS M 1:50 steht da: kein Befund") }
    else { $falsch++; $zeilen.Add("[FALSCH]       nur GRUNDRISS fehlt: $($nurGeschoss.Count) Befunde") }
    $geschossC = @($itemsC | Where-Object { [math]::Abs($_.Y - $titelC.Y) -le 3 -and $_.T -match '^(?i)\w*geschoss\w*$' })
    $b = @(Get-A11Planinhalt @($itemsC | Where-Object { $_ -ne $titelC -and $geschossC -notcontains $_ }) | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and $b[0].Angabe -eq 'Planbezeichnung') { $richtig++; $zeilen.Add("[richtig]      GRUNDRISS und Geschossname fehlen: Befund Planbezeichnung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne GRUNDRISS: $($b.Count) Befunde") }
    $b = @(Get-A11Planinhalt @($itemsC | Where-Object { $_ -ne $skalaC }) | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and $b[0].Angabe -eq 'Planbezeichnung') { $richtig++; $zeilen.Add("[richtig]      Maßstab in der Bezeichnung fehlt: Befund") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Maßstab in der Bezeichnung: $($b.Count) Befunde") }

    $s100 = @($itemsC | ForEach-Object { if ($_ -eq $skalaC) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = '1:100' } } else { $_ } })
    $b = @(Get-A11Planinhalt $s100 | Where-Object { -not $_.Ok })
    if (@($b | Where-Object { $_.Angabe -eq 'Maßstab' }).Count -eq 1 -and @($b | Where-Object { $_.Angabe -eq 'Maßstab im Plankopf' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Bezeichnung 1:100 im Werkplan: 'nicht 1:50' und 'passt nicht zum Plankopf'") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Bezeichnung 1:100: $(($b | ForEach-Object { $_.Angabe }) -join ', ')") }

    $kopfC = $itemsC | Where-Object { $_.T -eq '1:50' -and $_.X -gt 1200 } | Select-Object -First 1
    $kopf20 = @($itemsC | ForEach-Object { if ($_ -eq $kopfC) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = '1:20' } } else { $_ } })
    $b = @(Get-A11Planinhalt $kopf20 | Where-Object { -not $_.Ok })
    if ($b.Count -eq 1 -and $b[0].Angabe -eq 'Maßstab im Plankopf') { $richtig++; $zeilen.Add("[richtig]      Plankopf 1:20, Plan 1:50: ein Befund beim Plankopf") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Plankopf 1:20: $($b.Count) Befunde") }

    $b = @(Get-A11Planinhalt @($itemsC | Where-Object { $_ -ne $kopfC }) | Where-Object { -not $_.Ok })
    if ($b.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Maßstab im Plankopf nicht lesbar: Vergleich wird übersprungen, kein Befund") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Kopf-Maßstab: $($b.Count) Befunde") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A11*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A11 läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A11 ist auch im Entwurf aktiv") }
}
# Selbsttest A9: Achsraster aus Strichpunktlinien (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A9' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A9: Achsen (Strichpunktlinien)")
    $itemsD = @(Get-PdfTextItems $werkOk.FullName)
    $linienD = @(Get-PdfLinien $werkOk.FullName)
    $achsD = @(Get-AchsenLinien $linienD)
    $senkD = @($achsD | Where-Object { $_.Richtung -eq 'senkrecht' }); $waagD = @($achsD | Where-Object { $_.Richtung -eq 'waagrecht' })
    $r = @(Get-A9Achsen $itemsD $linienD)
    if ($senkD.Count -eq 5 -and $waagD.Count -eq 3 -and $r.Count -eq 1 -and $r[0].Ok -and $r[0].Wert -match 'A, B, C, D, E') { $richtig++; $zeilen.Add("[richtig]      Musterplan: 5 senkrechte und 3 waagrechte Achsenlinien, Bezeichnungen A bis E und 1 bis 3 gefunden") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: senkrecht=$($senkD.Count), waagrecht=$($waagD.Count), $(($r | ForEach-Object { "$($_.Ok) $($_.Wert) $($_.Detail)" }) -join ' | ')") }

    function Entferne-Achsen($linien, $achsen) {
        $linien | Where-Object {
            $l = $_
            -not (@($achsen | Where-Object {
                        ($_.Richtung -eq 'senkrecht' -and [math]::Abs($l.X1 - $l.X2) -lt 0.05 -and [math]::Abs($l.X1 - $_.Lage) -lt 0.2) -or
                        ($_.Richtung -eq 'waagrecht' -and [math]::Abs($l.Y1 - $l.Y2) -lt 0.05 -and [math]::Abs($l.Y1 - $_.Lage) -lt 0.2)
                    }).Count -gt 0)
        }
    }

    # Achsbezeichnungen (Buchstaben und Ziffern) fehlen: kein Fehler, die Linien zählen
    $ohneNamen = @($itemsD | Where-Object { $_.T -cnotmatch '^[A-Z1-9]$' })
    $b2 = @(Get-A9Achsen $ohneNamen $linienD)
    if ($b2[0].Ok -and $b2[0].Wert -match 'ohne Bezeichnungen') { $richtig++; $zeilen.Add("[richtig]      alle Achsbuchstaben und -ziffern fehlen: kein Fehler (die Linien zählen)") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Bezeichnungen: $($b2[0].Ok) $($b2[0].Wert) $($b2[0].Detail)") }

    # Nur Buchstaben fehlen / nur Ziffern fehlen: kein Fehler
    $ohneB = @($itemsD | Where-Object { $_.T -cnotmatch '^[A-Z]$' }); $ohneZ = @($itemsD | Where-Object { $_.T -notmatch '^[1-9]$' })
    if ((Get-A9Achsen $ohneB $linienD)[0].Ok -and (Get-A9Achsen $ohneZ $linienD)[0].Ok) { $richtig++; $zeilen.Add("[richtig]      nur Buchstaben oder nur Ziffern fehlen: kein Fehler") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Buchstaben oder Ziffern allein entfernt: Befund") }

    # Nur ein Raster in einer Richtung (waagrecht oder senkrecht): in Ordnung
    $nurSenk = @(Entferne-Achsen $linienD $waagD); $nurWaag = @(Entferne-Achsen $linienD $senkD)
    $rs = @(Get-A9Achsen $itemsD $nurSenk); $rw = @(Get-A9Achsen $itemsD $nurWaag)
    if ($rs[0].Ok -and $rs[0].Wert -match '^5 senkrechte, 0 waag' -and $rw[0].Ok -and $rw[0].Wert -match '^0 senkrechte, 3 waag') { $richtig++; $zeilen.Add("[richtig]      nur senkrechte oder nur waagrechte Achsen: in Ordnung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       eine Richtung: $($rs[0].Wert) | $($rw[0].Wert)") }

    # Nur eine einzelne Achsenlinie: Befund
    $eine = @(Entferne-Achsen $linienD @($achsD | Where-Object { $_ -ne $senkD[0] }))
    $re = @(Get-A9Achsen $itemsD $eine)
    if (-not $re[0].Ok -and $re[0].Detail -match 'nur eine einzelne' -and $null -ne $re[0].X) { $richtig++; $zeilen.Add("[richtig]      nur eine einzelne Achsenlinie: Befund mit Position") }
    else { $falsch++; $zeilen.Add("[FALSCH]       eine Linie: $($re[0].Ok) $($re[0].Detail)") }

    # Alle Achsenlinien fehlen (die Bezeichnungen bleiben stehen): Befund
    $keine = @(Entferne-Achsen $linienD $achsD)
    $rk = @(Get-A9Achsen $itemsD $keine)
    if (-not $rk[0].Ok -and $rk[0].Detail -match 'kein Achsraster') { $richtig++; $zeilen.Add("[richtig]      alle Achsenlinien fehlen (nur Bezeichnungen): Befund 'kein Achsraster'") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Linien: $($rk[0].Ok) $($rk[0].Detail)") }
    $rl = @(Get-A9Achsen $itemsD @())
    if (-not $rl[0].Ok) { $richtig++; $zeilen.Add("[richtig]      gar keine Linien im Plan: Befund") } else { $falsch++; $zeilen.Add("[FALSCH]       ohne jede Linie kein Befund") }

    # Reine Strichlinien (ohne Punkte): zwei lange regelmäßige Linien zählen, kurze oder unregelmäßige nicht
    function Neue-Strichlinie($x, $y0, $anzahl, $strich, $luecke) { for ($i = 0; $i -lt $anzahl; $i++) { $a = $y0 + $i * ($strich + $luecke); [pscustomobject]@{ X1 = $x; Y1 = $a; X2 = $x; Y2 = $a + $strich; Laenge = $strich } } }
    $zwei = @((Neue-Strichlinie 100 100 50 12 5) + (Neue-Strichlinie 200 100 50 12 5))
    $rz = @(Get-A9Achsen @() $zwei)
    if ($rz[0].Ok) { $richtig++; $zeilen.Add("[richtig]      zwei lange reine Strichlinien (ohne Punkte) zählen als Raster") } else { $falsch++; $zeilen.Add("[FALSCH]       Strichlinien: $($rz[0].Detail)") }
    $kurz = @((Neue-Strichlinie 100 100 12 12 5) + (Neue-Strichlinie 200 100 12 12 5))
    $durchgezogen = @((Neue-Strichlinie 100 100 5 150 5) + (Neue-Strichlinie 200 100 5 150 5))
    $unregel = @(); foreach ($x in 100, 200) { $y = 100; foreach ($i in 1..40) { $s = 3 + (($i * 7) % 11); $unregel += [pscustomobject]@{ X1 = $x; Y1 = $y; X2 = $x; Y2 = $y + $s; Laenge = $s }; $y += $s + 4 } }
    if (-not (Get-A9Achsen @() $kurz)[0].Ok -and -not (Get-A9Achsen @() $durchgezogen)[0].Ok -and -not (Get-A9Achsen @() $unregel)[0].Ok) { $richtig++; $zeilen.Add("[richtig]      kurze, durchgezogene und unregelmäßige Linien zählen nicht als Achsen") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Sonderfälle (kurz/durchgezogen/unregelmäßig) wurden als Achsen erkannt") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A9*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A9 läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A9 ist auch im Entwurf aktiv") }
}
# Selbsttest A2: Bemaßung (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A2' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A2: Bemaßung (Maßketten, Gesamtmaß, Achsmaße, Schreibweise)")
    $itemsM = @(Get-PdfTextItems $werkOk.FullName)
    $linienM = @(Get-PdfLinienCached $werkOk.FullName)
    $kernM = Get-A2Kern $itemsM $linienM
    $r = @(Get-A2Massketten $itemsM $linienM)
    if ($kernM.Quelle -eq 'Achsraster' -and $r.Count -eq 4 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0 -and @($r | Where-Object { $_.Wert -match 'Gesamtmaß 15,99 = Summe' }).Count -eq 2 -and @($r | Where-Object { $_.Wert -match 'Gesamtmaß 13,49 = Summe' }).Count -eq 2) { $richtig++; $zeilen.Add("[richtig]      Musterplan: alle vier Seiten in Ordnung (Gesamtmaß 15,99 und 13,49 gleich Summe, Achsmaße stimmen)") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok) $($_.Detail)" }) -join ' | ')") }

    function Ersetze-Text($alle, $item, $neuerText) { @($alle | ForEach-Object { if ($_ -eq $item) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = $neuerText } } else { $_ } }) }
    function Nur-Befund($erwartetSeite, $erwartetText, $items2, $linien2, $name) {
        $b = @(Get-A2Massketten $items2 $linien2 | Where-Object { -not $_.Ok })
        if ($b.Count -eq 1 -and $b[0].Angabe -eq "Maßkette $erwartetSeite" -and $b[0].Detail -match $erwartetText -and $null -ne $b[0].X -and $null -ne $b[0].Y) { $script:richtig++; $script:zeilen.Add("[richtig]      $name") }
        else { $script:falsch++; $script:zeilen.Add("[FALSCH]       $name -> $($b.Count) Befunde ($(($b | ForEach-Object { "$($_.Angabe): $($_.Detail)" }) -join ' | '))") }
    }
    $oben133 = $itemsM | Where-Object { $_.T -eq '1,82' -and [math]::Abs($_.Y - 133) -lt 3 } | Select-Object -First 1
    $oben105 = $itemsM | Where-Object { $_.T -eq '15,99' -and [math]::Abs($_.Y - 105) -lt 3 } | Select-Object -First 1
    $oben77 = $itemsM | Where-Object { $_.T -eq '5,08' -and [math]::Abs($_.Y - 77) -lt 3 } | Select-Object -First 1

    Nur-Befund 'oben' 'stimmt mit keiner Maßkette überein' (Ersetze-Text $itemsM $oben133 '1,83') $linienM 'Teilmaß 1,82 -> 1,83 in der Öffnungsmaßkette oben: Gesamtmaß stimmt nicht mehr, ein Befund'
    Nur-Befund 'oben' 'stimmt mit keiner Maßkette überein' (Ersetze-Text $itemsM $oben105 '15,89') $linienM 'Gesamtmaß 15,99 -> 15,89 oben: ein Befund'
    Nur-Befund 'oben' 'fehlt das Gesamtmaß' @($itemsM | Where-Object { $_ -ne $oben105 }) $linienM 'Gesamtmaß oben fehlt: ein Befund'
    Nur-Befund 'oben' 'Achse zu Achse' (Ersetze-Text $itemsM $oben77 '5,18') $linienM 'Achsmaß 5,08 -> 5,18 oben: passt nicht zu den Achslinien'
    $zeile77 = @($itemsM | Where-Object { [math]::Abs($_.Y - 77) -lt 5 -and $_.X -gt 300 -and $_.X -lt 1100 })
    Nur-Befund 'oben' 'fehlt die Maßkette ''Achse zu Achse''' @($itemsM | Where-Object { $zeile77 -notcontains $_ }) $linienM 'ganze Kette Achse zu Achse oben fehlt: ein Befund'

    # Schreibweise: 78 cm als 0,78 und 1,13 mit 5 mm ohne Hochzahl als 1,135
    $cm78 = $itemsM | Where-Object { $_.T -eq '78' -and $_.X -lt 200 } | Select-Object -First 1
    Nur-Befund 'links' 'Schreibweise: Maße unter 1,00 m' (Ersetze-Text $itemsM $cm78 '0,78') $linienM 'Schreibweise 0,78 statt 78 (links): ein Befund'
    $m113 = $itemsM | Where-Object { $_.T -eq '1,13' -and [math]::Abs($_.Y - 48) -lt 3 } | Select-Object -First 1
    $hoch113 = $itemsM | Where-Object { $_.T -eq '5' -and [math]::Abs($_.X - ($m113.X + 17)) -lt 3 -and [math]::Abs($_.Y - ($m113.Y - 3.2)) -lt 2 } | Select-Object -First 1
    if ($m113 -and $hoch113) { Nur-Befund 'oben' 'Halbe Zentimeter stehen hochgestellt' @(Ersetze-Text @($itemsM | Where-Object { $_ -ne $hoch113 }) $m113 '1,135') $linienM 'Schreibweise 1,135 statt 1,13 mit Hochzahl (oben): ein Befund' }
    else { $falsch++; $zeilen.Add("[FALSCH]       Hochzahl neben 1,13 nicht gefunden") }

    # Eine ganze Seite fehlt
    foreach ($seite in 'oben', 'unten', 'links', 'rechts') {
        $ohne = @($itemsM | Where-Object { -not (($_.T -match '^\d{1,3}[.,]\d{2,3}$' -or $_.T -match '^\d{1,2}$') -and (Test-A2Seite $_ $kernM $seite)) })
        Nur-Befund $seite 'keine Maßkette' $ohne $linienM "Maßkette $seite ganz entfernt: genau ein Befund"
    }

    # Nur eine Richtung hat Achsen, die andere nicht (Achsen links/rechts entfernt): kein Befund bei Achse zu Achse für die fehlende Richtung
    # Ohne Achsraster: nicht geprüft, aber kein falscher Alarm
    $r2 = @(Get-A2Massketten $itemsM @())
    if ($r2.Count -eq 1 -and $r2[0].Ok -and $r2[0].Wert -eq 'nicht geprüft') { $richtig++; $zeilen.Add("[richtig]      ohne Achsraster: 'nicht geprüft' statt falschem Alarm") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Achsraster: $(($r2 | ForEach-Object { "$($_.Angabe)=$($_.Ok)" }) -join ', ')") }

    # BRH-Werte (0,00) im unteren Rand zählen nicht als Maßzahlen (kein falscher Schreibweise-Befund)
    $brhUnten = @($itemsM | Where-Object { $_.T -cmatch '^BRH' -and $_.Y -gt 960 }).Count
    if ($brhUnten -gt 0) { $richtig++; $zeilen.Add("[richtig]      BRH-Werte unten ($brhUnten Stück) im Musterplan werden nicht als Maßzahlen gezählt") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A2*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A2 läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A2 ist auch im Entwurf aktiv") }
}
# Selbsttest A8: Eingangspfeil (Pfeilspitzen aus den Strichen, Türbögen aus den Kurven)
if (@($script:Pruefungen | Where-Object { $_.Id -eq 'A8' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A8: Eingangspfeil (Pfeilspitze vor einer Tür)")
    function Neuer-Strich($x1, $y1, $x2, $y2) {
        $a = [pscustomobject]@{ X = $x1; Y = $y1 }; $b = [pscustomobject]@{ X = $x2; Y = $y2 }
        [pscustomobject]@{ Teile = @(, @($a, $b)); Art = 'strich'; Kurve = $false; X0 = [math]::Min($x1, $x2); Y0 = [math]::Min($y1, $y2); X1 = [math]::Max($x1, $x2); Y1 = [math]::Max($y1, $y2) }
    }
    function Neuer-Bogen($x0, $y0, $x1, $y1) { [pscustomobject]@{ Teile = @(, @([pscustomobject]@{ X = $x0; Y = $y0 })); Art = 'strich'; Kurve = $true; X0 = $x0; Y0 = $y0; X1 = $x1; Y1 = $y1 } }
    # Pfeil nach oben: Spitze bei (100,100), Schaft nach unten
    $pfeilHoch = @((Neuer-Strich 100 100 95 106), (Neuer-Strich 100 100 105 106), (Neuer-Strich 100 100 100 112))
    $tuerOben = Neuer-Bogen 90 70 114 94        # Tür liegt oberhalb der Spitze (der Pfeil zeigt hin)
    $tuerUnten = Neuer-Bogen 90 118 114 142     # Tür liegt unterhalb (der Pfeil zeigt weg)
    $tuerFern = Neuer-Bogen 400 70 424 94

    $r = @(Get-A8Eingangspfeil (@($pfeilHoch) + $tuerOben))
    if ($r.Count -eq 1 -and $r[0].Ok -and $r[0].Wert -match 'an einer Tür') { $richtig++; $zeilen.Add("[richtig]      Pfeil vor einer Tür, zeigt auf sie: in Ordnung") } else { $falsch++; $zeilen.Add("[FALSCH]       Pfeil vor Tür: $(($r | ForEach-Object { "$($_.Ok) $($_.Detail)" }) -join ' | ')") }
    $r = @(Get-A8Eingangspfeil (@($pfeilHoch) + $tuerUnten))
    if ($r.Count -eq 1 -and -not $r[0].Ok -and $r[0].Detail -match 'nicht in der Nähe einer Tür|keine in der Nähe') { $richtig++; $zeilen.Add("[richtig]      Pfeil zeigt von der Tür weg: Befund") } else { $falsch++; $zeilen.Add("[FALSCH]       Pfeil von Tür weg: $(($r | ForEach-Object { "$($_.Ok) $($_.Detail)" }) -join ' | ')") }
    $r = @(Get-A8Eingangspfeil (@($pfeilHoch) + $tuerFern))
    if ($r.Count -eq 1 -and -not $r[0].Ok) { $richtig++; $zeilen.Add("[richtig]      Pfeil weit von der Tür entfernt: Befund") } else { $falsch++; $zeilen.Add("[FALSCH]       Pfeil fern der Tür: $(($r | ForEach-Object { "$($_.Ok) $($_.Detail)" }) -join ' | ')") }
    $r = @(Get-A8Eingangspfeil @($tuerOben))
    if ($r.Count -eq 1 -and -not $r[0].Ok -and $r[0].Detail -match 'kein Eingangspfeil') { $richtig++; $zeilen.Add("[richtig]      Tür ohne Pfeil im Plan: Befund 'kein Eingangspfeil'") } else { $falsch++; $zeilen.Add("[FALSCH]       ohne Pfeil: $(($r | ForEach-Object { "$($_.Ok) $($_.Detail)" }) -join ' | ')") }
    # Rechtwinklige Ecken (Wände) und waagrechte oder senkrechte Striche sind keine Pfeilspitzen
    $waende = @((Neuer-Strich 100 100 100 112), (Neuer-Strich 100 100 112 100), (Neuer-Strich 100 100 90 100))
    if (@(Get-PfeilSpitzen @(Get-PfadStriche $waende)).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Wandecken (waagrechte und senkrechte Striche) sind keine Pfeilspitzen") } else { $falsch++; $zeilen.Add("[FALSCH]       Wandecke als Pfeilspitze erkannt") }

    # Die fünf Beispiele aus testplaene\Eingangspfeile.pdf (Linienpfeil, Pfeil mit Dreieck, gefülltes Dreieck, Umriss-Dreieck, kleiner Pfeil)
    $beispiele = Join-Path $ordner 'Eingangspfeile.pdf'
    if (Test-Path $beispiele) {
        $pfadeB = @(Get-PdfPfadeCached $beispiele)
        $spB = @(Get-PfeilSpitzen @(Get-PfadStriche $pfadeB))
        $rB = @(Get-A8Eingangspfeil $pfadeB)
        if ($spB.Count -eq 5 -and @(Get-TuerBoegen $pfadeB).Count -eq 5 -and $rB.Count -eq 1 -and $rB[0].Ok -and $rB[0].Wert -match '^5 Pfeil') { $richtig++; $zeilen.Add("[richtig]      Eingangspfeile.pdf: alle 5 Pfeilformen vor ihrer Tür erkannt (Linienpfeil, Pfeil mit Dreieck, gefüllt, Umriss, klein)") }
        else { $falsch++; $zeilen.Add("[FALSCH]       Eingangspfeile.pdf: $($spB.Count) Spitzen, $(@(Get-TuerBoegen $pfadeB).Count) Türbögen, $(($rB | ForEach-Object { "$($_.Ok) $($_.Wert) $($_.Detail)" }) -join ' | ')") }
        # Alle Pfeile entfernen (alle kleinen geraden Striche und Füllungen im Umkreis der Spitzen): kein Eingangspfeil mehr
        $ohnePfeile = @($pfadeB | Where-Object {
                $q = $_
                -not ($q.Kurve -eq $false -and ($q.X1 - $q.X0) -le 20 -and ($q.Y1 - $q.Y0) -le 20 -and @($spB | Where-Object { [math]::Abs((($q.X0 + $q.X1) / 2) - $_.X) -le 15 -and [math]::Abs((($q.Y0 + $q.Y1) / 2) - $_.Y) -le 18 }).Count -gt 0)
            })
        $rO = @(Get-A8Eingangspfeil $ohnePfeile)
        if ($rO.Count -eq 1 -and -not $rO[0].Ok) { $richtig++; $zeilen.Add("[richtig]      Eingangspfeile.pdf ohne die Pfeile: Befund") } else { $falsch++; $zeilen.Add("[FALSCH]       ohne Pfeile: $(($rO | ForEach-Object { "$($_.Ok) $($_.Wert) $($_.Detail)" }) -join ' | ')") }
    } else { $zeilen.Add("[übersprungen] testplaene\Eingangspfeile.pdf nicht vorhanden") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A8*' }).Count -eq 1 -and @(Get-AktivePruefungen 'werk' | Where-Object { $_ -like 'A8*' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      A8 läuft in Entwurf und Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A8 ist nicht in beiden Phasen aktiv") }
}
# Selbsttest A2M: Maßzahl zu Maßlinie (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A2M' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A2M: Maßzahl zu Maßlinie (außen und innen)")
    $itemsL = @(Get-PdfTextItems $werkOk.FullName)
    $linienL = @(Get-PdfLinienCached $werkOk.FullName)
    $r = @(Get-A2mPruefung $itemsL $linienL)
    if ($r.Count -eq 1 -and $r[0].Ok -and [int]($r[0].Wert -replace '\D.*', '') -ge 80) { $richtig++; $zeilen.Add("[richtig]      Musterplan: $($r[0].Wert) (außen und innen), keine Befunde") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | ForEach-Object { "$($_.Ok) $($_.Wert) $($_.Detail)" }) -join ' | ')") }

    function Ersetze-L($alle, $item, $neuerText) { @($alle | ForEach-Object { if ($_ -eq $item) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = $neuerText } } else { $_ } }) }
    function Befund-L($zahlText, $y, $neuText, $erwartung, $name, $xMin = 0, $xMax = 99999) {
        $n = $itemsL | Where-Object { $_.T -eq $zahlText -and [math]::Abs($_.Y - $y) -lt 3 -and $_.X -ge $xMin -and $_.X -le $xMax } | Select-Object -First 1
        if (-not $n) { $script:falsch++; $script:zeilen.Add("[FALSCH]       $name -> Zahl $zahlText bei Y $y nicht gefunden"); return }
        $b = @(Get-A2mPruefung (Ersetze-L $itemsL $n $neuText) $linienL | Where-Object { -not $_.Ok })
        $gut = if ($erwartung -eq 1) { $b.Count -eq 1 -and $b[0].Wert -eq $neuText -and $null -ne $b[0].X -and $null -ne $b[0].Y } else { $b.Count -eq 0 }
        if ($gut) { $script:richtig++; $script:zeilen.Add("[richtig]      $name") }
        else { $script:falsch++; $script:zeilen.Add("[FALSCH]       $name -> $($b.Count) Befunde ($(($b | ForEach-Object { $_.Detail }) -join ' | '))") }
    }
    Befund-L '2,43' 133 '2,63' 1 'Öffnungsmaß oben 2,43 -> 2,63: ein Befund mit Position'
    Befund-L '4,87' 48 '4,57' 1 'Achse zu Bauteil oben 4,87 -> 4,57: ein Befund'
    Befund-L '2,43' 315 '2,13' 1 'Öffnungsmaß links (senkrechte Kette) 2,43 -> 2,13: ein Befund' 0 200
    Befund-L '6,49' 415 '6,89' 1 'Innenkette im Gebäude 6,49 -> 6,89: ein Befund' 300 340
    Befund-L '2,43' 133 '2,45' 1 'Abweichung von 2 cm: ein Befund (Messung von Querstrich zu Querstrich, Team 18.11.)'
    Befund-L '2,43' 133 '2,44' 0 'Abweichung von 1 cm (Rundung) bleibt in der Toleranz: kein Befund'
    Befund-L '1,78' 133 '1,78' 0 'Stück am Kettenende 1,78 wird richtig gemessen (Querstrich zu Querstrich): kein Befund' 1000 1200
    Befund-L '1,78' 133 '1,73' 1 'Kettenende 1,78 -> 1,73: ein Befund (früher als Zeichenweise geduldet)' 1000 1200

    # Zahl ohne Maßlinie (zum Beispiel in einem Stempel) wird nicht beachtet
    $stempelZahl = @($itemsL) + [pscustomobject]@{ X = 500; Y = 300; T = '99,99' }
    $rs = @(Get-A2mPruefung $stempelZahl $linienL | Where-Object { -not $_.Ok })
    if ($rs.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Zahl ohne Maßlinie darunter wird nicht beachtet") } else { $falsch++; $zeilen.Add("[FALSCH]       Zahl ohne Maßlinie: $($rs.Count) Befunde") }

    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A2M*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A2M läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A2M ist auch im Entwurf aktiv") }
}
# Selbsttest A5: Flächenplausibilität (Fehler im Speicher nachgestellt)
if ($werkOk -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A5' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A5: Flächenplausibilität (Fläche, Umfang, Summe gegen Gebäude)")
    $itemsF = @(Get-PdfTextItems $werkOk.FullName)
    $linienF = @(Get-PdfLinienCached $werkOk.FullName)
    $stempelF = @(Get-A4WRaumstempel $itemsF)
    $r = @(Get-A5Flaechen $itemsF $linienF)
    $gm = Get-A2Gesamtmasse $itemsF $linienF
    if ($r.Count -eq 8 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0 -and [math]::Abs($gm.Breite - 15.99) -lt 0.001 -and [math]::Abs($gm.Tiefe - 13.49) -lt 0.001) { $richtig++; $zeilen.Add("[richtig]      Musterplan: 7 Räume und Gebäudesumme (175,25 von 215,71 m²) plausibel, Gesamtmaße 15,99 und 13,49 gelesen") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | Where-Object { -not $_.Ok } | ForEach-Object { "$($_.Angabe): $($_.Detail)" }) -join ' | ')") }

    function Ersetze-F($alle, $item, $neuerText) { @($alle | ForEach-Object { if ($_ -eq $item) { [pscustomobject]@{ X = $_.X; Y = $_.Y; T = $neuerText } } else { $_ } }) }
    function Befund-F($items2, $angabe, $detail, $name) {
        $b = @(Get-A5Flaechen $items2 $linienF | Where-Object { -not $_.Ok })
        if (@($b | Where-Object { $_.Angabe -eq $angabe -and $_.Detail -match $detail }).Count -ge 1 -and $b.Count -le 2) { $script:richtig++; $script:zeilen.Add("[richtig]      $name") }
        else { $script:falsch++; $script:zeilen.Add("[FALSCH]       $name -> $($b.Count) Befunde ($(($b | ForEach-Object { "$($_.Angabe): $($_.Detail)" }) -join ' | '))") }
    }
    $buero = $stempelF | Where-Object { $_.NameText -eq 'Büro' } | Select-Object -First 1
    $wohnen = $stempelF | Where-Object { $_.NameText -eq 'Wohnen/Essen' } | Select-Object -First 1
    $wc = $stempelF | Where-Object { $_.NameText -eq 'WC' } | Select-Object -First 1

    Befund-F (Ersetze-F $itemsF $buero.Felder['RU'].Wert '18,000') 'Raum Büro' 'zu klein' 'Büro: Umfang 18,00 m bei 31,39 m² (Quadrat hat 22,41 m): Befund'
    Befund-F (Ersetze-F $itemsF $buero.Felder['RU'].Wert '99,000') 'Raum Büro' 'unwahrscheinlich groß' 'Büro: Umfang 99,00 m bei 31,39 m²: Befund'
    Befund-F (Ersetze-F $itemsF $wc.Felder['NGF'].Wert '0,30') 'Raum WC' 'unwahrscheinlich klein' 'WC: Fläche 0,30 m²: Befund'
    Befund-F (Ersetze-F $itemsF $wohnen.Felder['NGF'].Wert '146,65') 'Raumflächen gesamt' 'mehr als das Gebäude' 'Wohnen/Essen 146,65 statt 46,65 m²: Summe größer als das Gebäude (Befund)'
    # WC genau quadratisch (RU = 4 mal Wurzel aus NGF) bleibt in Ordnung (Rundung): im Musterplan 3,76 und 7,760
    if (@($r | Where-Object { $_.Angabe -eq 'Raum WC' -and $_.Ok }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      WC mit quadratischem Grundriss (Umfang genau 4 mal Wurzel aus der Fläche) bleibt in Ordnung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       WC quadratisch") }

    # Fast alle Stempel fehlen: nur WC und Technik übrig, Hinweis 'nur x Prozent'
    $behalten = @($stempelF | Where-Object { $_.NameText -in 'WC', 'Technik' })
    $ohneAndere = @($itemsF | Where-Object {
            $i = $_
            -not (@($stempelF | Where-Object { $_.NameText -notin 'WC', 'Technik' } | Where-Object { [math]::Abs($i.X - $_.AnkerX) -le 60 -and $i.Y -ge ($_.Oben - 35) -and $i.Y -le ($_.Oben + 95) }).Count -gt 0)
        })
    $bb = @(Get-A5Flaechen $ohneAndere $linienF | Where-Object { -not $_.Ok })
    if ($bb.Count -eq 1 -and $bb[0].Angabe -eq 'Raumflächen gesamt' -and $bb[0].Detail -match 'Prozent') { $richtig++; $zeilen.Add("[richtig]      nur zwei kleine Räume im Plan: Hinweis 'deckt nur x Prozent ab'") }
    else { $falsch++; $zeilen.Add("[FALSCH]       fast keine Räume: $($bb.Count) Befunde ($(($bb | ForEach-Object { "$($_.Angabe): $($_.Detail)" }) -join ' | '))") }

    # Fehlende Angaben sind kein Fehler: Umfang oder Fläche ganz weg (Zeile entfernt)
    $ohneRu = @($itemsF | Where-Object { $_ -ne $buero.Felder['RU'].Wert -and $_ -ne $buero.Felder['RU'].Label })
    $rr = @(Get-A5Flaechen $ohneRu $linienF | Where-Object { -not $_.Ok })
    if ($rr.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Büro ohne RU-Zeile: kein Befund (fehlende Angabe ist kein Fehler)") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Büro ohne RU: $($rr.Count) Befunde") }

    # Ohne Achsraster: nur Raumprüfungen, keine Summe gegen das Gebäude
    $rk = @(Get-A5Flaechen $itemsF @())
    if ($rk.Count -eq 7 -and @($rk | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      ohne Achsraster: Räume geprüft, Gebäudesumme entfällt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Achsraster: $($rk.Count) Ergebnisse") }

    # Stufe 2: NGF und RU gegen die Wand-Maßketten (Hinweis ab 3 Prozent)
    $w = @(Get-A5Wandmasse $itemsF $linienF)
    $wOk = @($w | Where-Object { $_.Ok }); $wHin = @($w | Where-Object { -not $_.Ok })
    if ($wOk.Count -ge 5 -and @($wHin | Where-Object { $_.Quelle -ne 'hinweis' }).Count -eq 0 -and @($wOk | Where-Object { $_.Angabe -eq 'Raum Büro (Wandmaße)' -and $_.Wert -match '6,49' }).Count -eq 1) { $richtig++; $zeilen.Add("[richtig]      Wandmaße: $($wOk.Count) Räume passen zu den Wand-Maßketten (zum Beispiel Büro 6,49 m), $($wHin.Count) Hinweis(e), keine Fehler") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Wandmaße: $(($w | ForEach-Object { "$($_.Angabe)=$($_.Ok) $($_.Wert)" }) -join ' | ')") }
    # Seit 18.11.: nur sicher zugeordnete Maßketten (zwei Maße, Fläche oder Umfang auf 1 % genau) lösen einen Hinweis aus.
    # Büro hat nur eine passende Kette (6,49 m): eine falsche Fläche wird dort nicht mehr bestätigt, aber auch nicht gemeldet.
    $ngf10 = Ersetze-F $itemsF $buero.Felder['NGF'].Wert '34,53'
    $wb = @(Get-A5Wandmasse $ngf10 $linienF | Where-Object { $_.Angabe -eq 'Raum Büro (Wandmaße)' })
    if ($wb.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Büro NGF 34,53 statt 31,39 (nur eine Maßkette): nicht mehr bestätigt, kein unsicherer Hinweis") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Büro NGF +10 Prozent: $(($wb | ForEach-Object { "$($_.Ok) $($_.Quelle) $($_.Detail)" }) -join ' | ')") }
    # Technik hat zwei sichere Maße (3,54 mal 1,94 m): Fläche oder Umfang 10 % falsch gibt einen gelben Hinweis
    $technik = $stempelF | Where-Object { $_.NameText -eq 'Technik' } | Select-Object -First 1
    $wt = @(Get-A5Wandmasse (Ersetze-F $itemsF $technik.Felder['NGF'].Wert '7,60') $linienF | Where-Object { $_.Angabe -eq 'Raum Technik (Wandmaße)' })
    if ($wt.Count -eq 1 -and -not $wt[0].Ok -and $wt[0].Quelle -eq 'hinweis' -and $wt[0].Detail -match 'Hinweis') { $richtig++; $zeilen.Add("[richtig]      Technik NGF 7,60 statt 6,91 (10 Prozent zu groß, Umfang passt): gelber Hinweis") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Technik NGF +10 Prozent: $(($wt | ForEach-Object { "$($_.Ok) $($_.Quelle) $($_.Detail)" }) -join ' | ')") }
    $wr = @(Get-A5Wandmasse (Ersetze-F $itemsF $technik.Felder['RU'].Wert '12,010') $linienF | Where-Object { $_.Angabe -eq 'Raum Technik (Wandmaße)' })
    if ($wr.Count -eq 1 -and -not $wr[0].Ok -and $wr[0].Quelle -eq 'hinweis') { $richtig++; $zeilen.Add("[richtig]      Technik RU 12,01 statt 10,92 (10 Prozent zu groß, Fläche passt): Hinweis") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Technik RU +10 Prozent: $(($wr | ForEach-Object { "$($_.Ok) $($_.Quelle) $($_.Detail)" }) -join ' | ')") }
    # Wohnflächenberechnung: 3 % Putzabzug gilt als passend (Technik-Fläche 6,91 mal 0,97 = 6,70)
    $wp = @(Get-A5Wandmasse (Ersetze-F $itemsF $technik.Felder['NGF'].Wert '6,70') $linienF | Where-Object { $_.Angabe -eq 'Raum Technik (Wandmaße)' })
    if ($wp.Count -eq 1 -and $wp[0].Ok -and $wp[0].Wert -match 'Putzabzug') { $richtig++; $zeilen.Add("[richtig]      Technik NGF 6,70 (3 Prozent Putzabzug nach Wohnflächenberechnung): passt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Technik mit Putzabzug: $(($wp | ForEach-Object { "$($_.Ok) $($_.Quelle) $($_.Wert)" }) -join ' | ')") }
    # Raumhöhe unter 2 m: nach Wohnflächenberechnung nicht nachprüfbar, keine Meldung
    $wh = @(Get-A5Wandmasse (Ersetze-F (Ersetze-F $itemsF $technik.Felder['NGF'].Wert '7,60') $technik.Felder['RH'].Wert '1,800') $linienF | Where-Object { $_.Angabe -eq 'Raum Technik (Wandmaße)' })
    if ($technik.Felder['RH'].Wert -and $wh.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Technik mit RH 1,80 m: Fläche nach Wohnflächenberechnung nicht nachprüfbar, keine Meldung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Technik RH 1,80: $(if (-not $technik.Felder['RH'].Wert) { 'keine RH im Stempel' } else { ($wh | ForEach-Object { "$($_.Ok) $($_.Quelle)" }) -join ' | ' })") }
    $wl = @(Get-A5Wandmasse $itemsF @())
    if ($wl.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      ohne Maßlinien: Wandmaße nicht nachprüfbar, keine Meldung") } else { $falsch++; $zeilen.Add("[FALSCH]       ohne Maßlinien: $($wl.Count) Ergebnisse") }
    if (@(Get-AktivePruefungen 'entwurf' | Where-Object { $_ -like 'A5*' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A5 läuft nur in der Werkplanung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A5 ist auch im Entwurf aktiv") }
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

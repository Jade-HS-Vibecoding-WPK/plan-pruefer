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
        if ($f.BaseName -notmatch '^\d+_(?<punkt>A\d*[A-Z]?)_(?<art>ok|fehler)') {
            $uebersprungen++
            $zeilen.Add("[übersprungen] $($f.Name)  (Name passt nicht zum Schema <nr>_<A4>_<ok|fehler>)")
            continue
        }
        $punkt = $Matches['punkt']; $art = $Matches['art']

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

# Selbsttest A6: Schnittlinien (Buchstabe an beiden Enden)
if ($okPlan -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A6' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest A6: Schnittlinien")
    $itemsA6 = @(Get-PdfTextItems $okPlan.FullName)
    $r = @(Get-A6Schnittlinien $itemsA6)
    if (@($r | Where-Object { $_.Ok -and $_.Angabe -eq 'Schnitt A' }).Count -eq 1 -and @($r | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Musterplan: Schnitt A an beiden Enden erkannt, keine Befunde") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Musterplan: $(($r | ForEach-Object { "$($_.Angabe)=$($_.Ok)" }) -join ', ')") }

    $enden = @($itemsA6 | Where-Object { $_.T -ceq 'A' } | Sort-Object Y)
    if ($enden.Count -eq 2) {
        $einEnde = @($itemsA6 | Where-Object { $_ -ne $enden[1] })
        $r = @(Get-A6Schnittlinien $einEnde | Where-Object { -not $_.Ok })
        if ($r.Count -eq 1 -and $r[0].Angabe -eq 'Schnitt A') { $richtig++; $zeilen.Add("[richtig]      fehlt ein Ende, wird 'Schnitt A nur an einem Ende' gemeldet") }
        else { $falsch++; $zeilen.Add("[FALSCH]       ein Ende entfernt: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Angabe }) -join ', '))") }

        $keiner = @($itemsA6 | Where-Object { $_ -ne $enden[0] -and $_ -ne $enden[1] })
        $r = @(Get-A6Schnittlinien $keiner | Where-Object { -not $_.Ok })
        if ($r.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      Schnittlinie ohne Buchstaben ist in Ordnung (kein Befund)") }
        else { $falsch++; $zeilen.Add("[FALSCH]       beide Enden entfernt: $($r.Count) Befunde ($(($r | ForEach-Object { $_.Angabe }) -join ', '))") }
    }

    # Ein einzelnes N (Nordpfeil) ist kein Schnitt; zwei gleiche Buchstaben dicht beieinander sind kein Schnitt
    $nurN = @([pscustomobject]@{ X = 1000; Y = 60; T = 'N' })
    $r = @(Get-A6Schnittlinien $nurN | Where-Object { -not $_.Ok })
    $dicht = @([pscustomobject]@{ X = 100; Y = 100; T = 'B' }, [pscustomobject]@{ X = 100; Y = 150; T = 'B' })
    $r2 = @(Get-A6Schnittlinien $dicht | Where-Object { -not $_.Ok })
    $waagrecht = @([pscustomobject]@{ X = 100; Y = 300; T = 'C' }, [pscustomobject]@{ X = 600; Y = 303; T = 'C' })
    $r3 = @(Get-A6Schnittlinien $waagrecht)
    if ($r.Count -eq 0 -and $r2.Count -eq 2 -and @($r3 | Where-Object { $_.Ok }).Count -eq 1 -and @($r3 | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      N ist kein Schnitt, dichte Buchstaben sind kein Paar, waagerechte Schnitte werden erkannt") }
    else { $falsch++; $zeilen.Add("[FALSCH]       Sonderfälle: nurN=$($r.Count), dicht=$($r2.Count), waagrecht ok=$(@($r3 | Where-Object { $_.Ok }).Count)") }
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

# Selbsttest KI-Anbindung: ohne echten Aufruf (die KI wird hier nur nachgestellt, es wird nichts gesendet).
if ($okPlan -and @($script:Pruefungen | Where-Object { $_.Id -eq 'A3K' }).Count -gt 0) {
    $zeilen.Add("")
    $zeilen.Add("== Selbsttest KI (A3K, A7K), ohne echten Aufruf")
    $anzahlKi = @($script:Pruefungen | Where-Object { $_.Ki -and $_.Phasen -contains 'entwurf' }).Count

    # 0. A7K: Antwort der KI wird richtig umgewandelt
    $antwort7 = '{"bereiche":[{"art":"Stufe","lage":"rechts unten, Eingang","x_prozent":80,"y_prozent":90}]}' | ConvertFrom-Json
    $e = @(ConvertTo-A7KErgebnisse $antwort7)
    if ($e.Count -eq 1 -and -not $e[0].Ok -and $e[0].Quelle -eq 'ki' -and $e[0].Detail -match 'Stufe' -and $e[0].Detail -match 'rechts unten') { $richtig++; $zeilen.Add("[richtig]      A7K: KI-Antwort wird zu einem KI-Hinweis mit Art und Lage") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A7K: KI-Antwort wurde nicht richtig umgewandelt: $($e | ConvertTo-Json -Compress)") }

    # A6K: Antwort der KI wird richtig umgewandelt
    $antwort6 = '{"anzahl_schnittlinien":1,"probleme":[{"problem":"dreieck_fehlt","bezeichnung":"A","lage":"senkrecht in der Mitte","x_prozent":35,"y_prozent":50}]}' | ConvertFrom-Json
    $e = @(ConvertTo-A6KErgebnisse $antwort6)
    if ($e.Count -eq 1 -and -not $e[0].Ok -and $e[0].Quelle -eq 'ki' -and $e[0].Angabe -match 'Schnitt A' -and $e[0].Detail -match 'senkrecht' -and $e[0].Detail -match 'Dreieck') { $richtig++; $zeilen.Add("[richtig]      A6K: fehlendes Dreieck wird zu einem KI-Hinweis mit Schnittbezeichnung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A6K: KI-Antwort wurde nicht richtig umgewandelt: $($e | ConvertTo-Json -Compress)") }
    $e = @(ConvertTo-A6KErgebnisse ('{"anzahl_schnittlinien":0,"probleme":[]}' | ConvertFrom-Json))
    if ($e.Count -eq 1 -and $e[0].Angabe -eq 'Schnittlinie' -and $e[0].Detail -match 'keine Schnittlinie') { $richtig++; $zeilen.Add("[richtig]      A6K: keine Schnittlinie im Plan wird gemeldet") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A6K: 0 Schnittlinien ergab $($e.Count) Befunde") }
    $e = @(ConvertTo-A6KErgebnisse ('{"anzahl_schnittlinien":2,"probleme":[{"problem":"richtung_unterschiedlich","lage":"waagerecht unten"}]}' | ConvertFrom-Json))
    if ($e.Count -eq 1 -and $e[0].Detail -match 'unterschiedliche Richtungen') { $richtig++; $zeilen.Add("[richtig]      A6K: unterschiedliche Richtung der Dreiecke wird gemeldet") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A6K: unterschiedliche Richtung ergab $($e.Count) Befunde") }
    $e = @(ConvertTo-A6KErgebnisse ('{"anzahl_schnittlinien":1,"probleme":[]}' | ConvertFrom-Json))
    if ($e.Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      A6K: eine Schnittlinie ohne Probleme ergibt keinen Befund") }
    else { $falsch++; $zeilen.Add("[FALSCH]       A6K: korrekte Schnittlinie ergab $($e.Count) Befunde") }

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
    $script:TestKiAntwort = '{"weitere_raeume":[{"lage":"rechts unten"}],"bereiche":[],"anzahl_schnittlinien":1,"probleme":[]}' | ConvertFrom-Json
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
    $script:TestKiAntwort = '{"weitere_raeume":[{"lage":"rechts unten"}],"bereiche":[],"anzahl_schnittlinien":1,"probleme":[]}' | ConvertFrom-Json

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

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
    # Sobald A7 (Höhenangaben) gebaut ist, ist dieser Plan zugleich der Fehlerfall für A7.
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
    $zeilen.Add("== Selbsttest KI (A3K), ohne echten Aufruf")

    # 1. Antwort der KI wird richtig in Befunde umgewandelt
    $antwort = '{"raeume":[{"lage":"links oben, neben dem Flur","x_prozent":12.4,"y_prozent":30}]}' | ConvertFrom-Json
    $e = @(ConvertTo-A3KErgebnisse $antwort)
    if ($e.Count -eq 1 -and -not $e[0].Ok -and $e[0].Quelle -eq 'ki' -and $e[0].Detail -match 'links oben' -and $e[0].Detail -match '12 %') { $richtig++; $zeilen.Add("[richtig]      KI-Antwort wird zu einem KI-Hinweis mit Lage") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI-Antwort wurde nicht richtig umgewandelt: $($e | ConvertTo-Json -Compress)") }

    # 2. Leere Liste der KI ergibt keine Befunde
    $e = @(ConvertTo-A3KErgebnisse ('{"raeume":[]}' | ConvertFrom-Json))
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
    if ($script:TestKiAufrufe -eq 0 -and $m.Count -eq 1 -and $m[0] -match 'kein KI-Schlüssel' -and @($res | Where-Object { -not $_.Ok }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      ohne Schlüssel: keine KI-Anfrage, eine verständliche Meldung") }
    else { $falsch++; $zeilen.Add("[FALSCH]       ohne Schlüssel: Aufrufe=$($script:TestKiAufrufe), Meldungen=$($m.Count)") }

    # 4. KI nicht eingeschaltet: es wird keine Anfrage gestellt (Datenschutz)
    $script:TestKiAn = $true; $script:TestKiAufrufe = 0
    $script:TestKiAntwort = '{"raeume":[{"lage":"rechts unten"}]}' | ConvertFrom-Json
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $false)
    if ($script:TestKiAufrufe -eq 0 -and @($res | Where-Object { $_.Quelle -eq 'ki' }).Count -eq 0) { $richtig++; $zeilen.Add("[richtig]      KI aus: es wird nichts an die KI gesendet") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI aus, aber Aufrufe=$($script:TestKiAufrufe)") }

    # 5. KI eingeschaltet: genau eine Anfrage, der Hinweis erscheint als Befund mit Punkt A3K
    $script:TestKiAufrufe = 0
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $ki = @($res | Where-Object { $_.Quelle -eq 'ki' })
    if ($script:TestKiAufrufe -eq 1 -and $ki.Count -eq 1 -and $ki[0].Punkt -eq 'A3K') { $richtig++; $zeilen.Add("[richtig]      KI ein: eine Anfrage, KI-Hinweis als Befund A3K") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI ein: Aufrufe=$($script:TestKiAufrufe), KI-Befunde=$($ki.Count)") }

    # 6. Fehler der KI (zum Beispiel Limit): Meldung statt Absturz, normale Prüfungen laufen weiter
    $script:TestKiFehler = 'Das kostenlose KI-Limit ist erreicht.'
    $res = @(Invoke-Pruefungen $okPlan.FullName 'entwurf' $true)
    $m = @(Get-Meldungen)
    if ($m.Count -eq 1 -and $m[0] -match 'Limit' -and @($res | Where-Object { $_.Punkt -eq 'A4' -and $_.Ok }).Count -gt 0) { $richtig++; $zeilen.Add("[richtig]      KI-Fehler: Meldung, die anderen Prüfungen laufen weiter") }
    else { $falsch++; $zeilen.Add("[FALSCH]       KI-Fehler: Meldungen=$($m.Count)") }
}

$zeilen | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host ("Ergebnis: {0} richtig, {1} falsch, {2} übersprungen (von {3} Prüfungen)" -f $richtig, $falsch, $uebersprungen, ($richtig + $falsch + $uebersprungen))

<#
  Testlauf: Lässt die Plankopf-Prüfung über alle Pläne in ..\testplaene laufen
  und vergleicht das Ergebnis mit der Erwartung.

  Aufruf:
    .\testlauf.ps1
#>
. "$PSScriptRoot\plankopf-pruefung.ps1"

$ordner = Join-Path $PSScriptRoot '..\..\testplaene'

# Erwartung: welche Angabe soll bei welchem Plan als fehlend gemeldet werden?
# (leere Liste = der Plan ist in Ordnung, es darf nichts gemeldet werden)
$erwartung = @{
    '02_einfamilienhaus_falsch'  = $null            # Nordpfeil: erst ab Stufe 2 prüfbar
    '03_einfamilienhaus_falsch'  = @('Projektname')
    '04_einfamilienhaus_falsch'  = @('Projektort')
    '05_einfamilienhaus_falsch'  = @('Bauherr')
    '06_einfamilienhaus_falsch'  = @('Planbezeichnung')
    '07_einfamilienhaus_falsch'  = @('Planer')
    '08_einfamilienhaus_falsch'  = @('Datum')
    '09_einfamilienhaus_falsch'  = @('Maßstab')
    '10_einfamilienhaus_falsch'  = @('Plannummer')
}

# Bei den Plänen in Ordnung prüfen wir zusätzlich, ob der gefundene Wert der richtige ist
# (sonst könnte das Tool "vorhanden" melden, aber den falschen Text gelesen haben).
$sollWerte = @{
    '01_einfamilienhaus_ok'  = @{ Projektname = 'Einfamilienwohnhaus'; Bauherr = 'Mustermann'; Projektort = 'Oldenburg'; Planer = 'Lina'; Plannummer = '02' }
    '02_einfamilienhaus_ok'  = @{ Projektname = 'Einfamilienwohnhaus'; Bauherr = 'Mustermann'; Projektort = 'Oldenburg'; Planer = 'Lina'; Plannummer = '02' }
    '02_einfamileienhaus_ok_plankopf variante 2' = @{ Projektname = 'Einfamilienwohnhaus'; Bauherr = 'Max Mustermann'; Projektort = 'Musterstr'; Planer = 'Maxine Maus'; Plannummer = 'G01' }
    '02_einfamileienhaus_ok_plankopf variante 3' = @{ Projektname = 'Einfamilienwohnhaus'; Bauherr = 'Maurer'; Projektort = 'Oldenburg'; Planer = 'Max Mustermann'; Plannummer = 'G01' }
}

$ok = 0; $fail = 0; $skip = 0
$lines = @()
foreach ($f in Get-ChildItem $ordner -Filter *.pdf | Sort-Object Name) {
    $key = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    if ($erwartung.ContainsKey($key)) { $soll = $erwartung[$key] }
    elseif ($key -match '_ok') { $soll = @() }
    else { continue }

    if ($null -eq $soll) {
        $skip++
        $lines += ("[übersprungen] {0}  (Nordpfeil ist eine Zeichnung, erst ab Stufe 2)" -f $f.Name)
        continue
    }

    $res = @(Test-Plankopf $f.FullName)
    $ist = @($res | Where-Object { -not $_.Ok } | ForEach-Object { $_.Angabe })
    $uebersehen = @($soll | Where-Object { $ist -notcontains $_ })
    $falscheAlarme = @($ist | Where-Object { $soll -notcontains $_ })

    $falscheWerte = @()
    if ($sollWerte.ContainsKey($key)) {
        foreach ($feld in $sollWerte[$key].Keys) {
            $r = $res | Where-Object { $_.Angabe -eq $feld } | Select-Object -First 1
            if ($r -and ($r.Wert -notlike ('*' + $sollWerte[$key][$feld] + '*'))) {
                $falscheWerte += "$feld gelesen: [$($r.Wert)], erwartet: [$($sollWerte[$key][$feld])]"
            }
        }
    }

    if ($uebersehen.Count -eq 0 -and $falscheAlarme.Count -eq 0 -and $falscheWerte.Count -eq 0) {
        $ok++
        $lines += ("[richtig]      {0}" -f $f.Name)
    } else {
        $fail++
        $msg = "[FALSCH]       $($f.Name)"
        foreach ($w in $falscheWerte) { $msg += "`n                 falscher Wert: " + $w }
        if ($uebersehen.Count -gt 0) { $msg += "`n                 übersehen:     " + ($uebersehen -join ', ') }
        if ($falscheAlarme.Count -gt 0) {
            $details = $res | Where-Object { $falscheAlarme -contains $_.Angabe } | ForEach-Object { "$($_.Angabe) ($($_.Detail))" }
            $msg += "`n                 falscher Alarm: " + ($details -join '; ')
        }
        $lines += $msg
    }
}

Write-Host ""
$lines | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host ("Ergebnis: {0} richtig, {1} falsch, {2} übersprungen (von {3} Plänen)" -f $ok, $fail, $skip, ($ok + $fail + $skip))

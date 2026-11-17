<#
  A4W Werk-Raumstempel: Stimmen Raumnummern, Raumhöhen im erweiterten Werk-Stempel?

  Der erweiterte Stempel der Werkplanung (untereinander):

      Büro               Raumname
      02                 Raumnummer (zweistellig)
      NGF: 31,39 m²      Fläche
      RU:  22,640 m      Raumumfang
      RH:  2,650 m       Raumhöhe
      FB:  Parkett       Fußbodenbelag
      WB:  Putz          Wandbelag
      DB:  Putz          Deckenbelag

  Entscheidung vom Team (17.11.): Wie vollständig der erweiterte Stempel ist, ist von Plan zu Plan
  verschieden. Fehlende Angaben (Raumnummer, RU, RH, FB, WB, DB) sind deshalb KEIN Fehler.
  Pflicht sind nur Raumname und Flächenzahl. Das prüfen A3 (Raumname) und A4 (Fläche), die auch in der
  Werkplanung laufen. A4W prüft nur das, was im Plan vorhanden ist:
    1. Raumnummern (falls vorhanden): keine doppelt, lückenlos in der Reihenfolge.
       Steht bei einem Raum keine Nummer, obwohl andere Räume eine haben, wird auch das gemeldet.
       Hat kein Raum eine Nummer, wird nichts gemeldet.
    2. Raumhöhe RH (falls vorhanden): muss zwischen 2,00 m und 6,00 m liegen.
  Später (mit den Maßketten, A2/A5): Plausibilität von Fläche und Raumumfang.

  Ein Stempel wird an der Spalte der Beschriftungen (NGF:, RU:, ...) erkannt. "Treppenholm" ist kein Raum.
#>

$script:A4wFelder = @(
    @{ Label = 'NGF'; Name = 'Fläche (NGF)';          Art = 'zahl' },
    @{ Label = 'RU';  Name = 'Raumumfang (RU)';       Art = 'zahl' },
    @{ Label = 'RH';  Name = 'Raumhöhe (RH)';         Art = 'zahl' },
    @{ Label = 'FB';  Name = 'Fußbodenbelag (FB)';    Art = 'wort' },
    @{ Label = 'WB';  Name = 'Wandbelag (WB)';        Art = 'wort' },
    @{ Label = 'DB';  Name = 'Deckenbelag (DB)';      Art = 'wort' }
)
$script:A4wZeilenabstand = 13.9

function Get-A4WStempelSpalten($items) {
    $labels = @($items | Where-Object { $_.T -cmatch '^(NGF|RU|RH|FB|WB|DB)\s*:$' } | Sort-Object { [math]::Round($_.X / 6) }, Y)
    $spalten = New-Object System.Collections.ArrayList
    $rest = New-Object System.Collections.Generic.List[object]
    foreach ($l in $labels) { $rest.Add($l) }
    while ($rest.Count -gt 0) {
        $erster = $rest[0]
        $sp = @($rest | Where-Object { [math]::Abs($_.X - $erster.X) -le 3 } | Sort-Object Y)
        foreach ($s in $sp) { [void]$rest.Remove($s) }
        # In Gruppen aufteilen: neue Gruppe, wenn der Abstand zu groß ist oder die Beschriftung sich wiederholt
        $gruppe = New-Object System.Collections.Generic.List[object]
        foreach ($s in $sp) {
            $kurz = ($s.T -replace '\s*:$', '')
            $doppelt = @($gruppe | Where-Object { ($_.T -replace '\s*:$', '') -ceq $kurz }).Count -gt 0
            $luecke = $gruppe.Count -gt 0 -and ($s.Y - $gruppe[$gruppe.Count - 1].Y) -gt 3 * $script:A4wZeilenabstand
            if ($gruppe.Count -gt 0 -and ($doppelt -or $luecke)) { [void]$spalten.Add($gruppe.ToArray()); $gruppe = New-Object System.Collections.Generic.List[object] }
            $gruppe.Add($s)
        }
        if ($gruppe.Count -gt 0) { [void]$spalten.Add($gruppe.ToArray()) }
    }
    ,$spalten.ToArray()
}

# Liest alle Werk-Raumstempel: pro Stempel Name, Nummer, Position und je Feld den Wert (oder $null).
function Get-A4WRaumstempel($items) {
    $reihenfolge = @($script:A4wFelder | ForEach-Object { $_.Label })
    foreach ($gruppe in (Get-A4WStempelSpalten $items)) {
        $gruppe = @($gruppe)
        $ankerX = ($gruppe | Measure-Object X -Average).Average
        # Oberkante des Stempels (Zeile "NGF:"), auch wenn diese Beschriftung selbst fehlt
        $oben = ($gruppe | ForEach-Object {
                $idx = [array]::IndexOf($reihenfolge, ($_.T -replace '\s*:$', ''))
                $_.Y - $idx * $script:A4wZeilenabstand
            } | Measure-Object -Average).Average

        $darueber = @($items | Where-Object {
                [math]::Abs($_.X - $ankerX) -le 3 -and $_.Y -lt ($oben - 5) -and $_.Y -gt ($oben - 40) -and $_.T -cnotmatch '^(NGF|RU|RH|FB|WB|DB)\s*:$'
            })
        $nummer = $darueber | Where-Object { $_.T -match '^\d{2}$' } | Sort-Object { [math]::Abs($_.Y - ($oben - 14.8)) } | Select-Object -First 1
        $name = $darueber | Where-Object { $_.T -match '[A-Za-zÄÖÜäöüß]{2,}' } | Sort-Object { [math]::Abs($_.Y - ($oben - 29)) } | Select-Object -First 1

        $felder = @{}
        foreach ($f in $script:A4wFelder) {
            $zeileY = $oben + [array]::IndexOf($reihenfolge, $f.Label) * $script:A4wZeilenabstand
            $label = $gruppe | Where-Object { ($_.T -replace '\s*:$', '') -ceq $f.Label } | Select-Object -First 1
            $wert = $null
            if ($label) {
                $kand = @($items | Where-Object {
                        [math]::Abs($_.Y - $label.Y) -le 2.5 -and $_.X -gt ($label.X + 5) -and ($_.X - $label.X) -le 110 -and $_.T -cnotmatch '^(NGF|RU|RH|FB|WB|DB)\s*:$'
                    } | Sort-Object X)
                if ($f.Art -eq 'zahl') { $wert = $kand | Where-Object { $_.T -match '^\d{1,4}[.,]\d{1,3}$' -or $_.T -match '^\d{1,4}$' } | Select-Object -First 1 }
                else { $wert = $kand | Where-Object { $_.T -match '[A-Za-zÄÖÜäöüß]{2,}' } | Select-Object -First 1 }
            }
            $felder[$f.Label] = [pscustomobject]@{ Label = $label; Wert = $wert; ZeileY = $zeileY }
        }
        [pscustomobject]@{
            Name     = $name
            NameText = $(if ($name) { $name.T } else { $null })
            Nummer   = $nummer
            AnkerX   = $ankerX
            Oben     = $oben
            Felder   = $felder
        }
    }
}

function Get-A4WWerkRaumstempel($items) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $stempel = @(Get-A4WRaumstempel $items)

    function Zahl-Aus($text) {
        $z = 0.0
        [void][double]::TryParse(($text -replace ',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$z)
        $z
    }
    $raumname = { param($s) if ($s.NameText) { $s.NameText } elseif ($s.Nummer) { "Nr. $($s.Nummer.T)" } else { '(ohne Namen)' } }
    $pos = { param($s) if ($s.Name) { @($s.Name.X, $s.Name.Y) } else { @($s.AnkerX, ($s.Oben - 29)) } }

    # 1. Raumnummern (nur wenn welche vorhanden sind)
    $mitNummer = @($stempel | Where-Object { $_.Nummer })
    if ($mitNummer.Count -gt 0) {
        $gemeldet = New-Object System.Collections.Generic.HashSet[object]
        foreach ($gruppe in @($mitNummer | Group-Object { $_.Nummer.T } | Where-Object { $_.Count -gt 1 })) {
            foreach ($s in $gruppe.Group) {
                $raum = & $raumname $s; $p = & $pos $s
                $namen = (@($gruppe.Group | ForEach-Object { & $raumname $_ }) -join ', ')
                $ergebnisse.Add((New-Result "Raum $raum" $false "Nr. $($s.Nummer.T)" "Raum ${raum}: Raumnummer $($gruppe.Name) kommt mehrfach vor ($namen)." $p[0] $p[1]))
                [void]$gemeldet.Add($s)
            }
        }
        $zahlen = @($mitNummer | ForEach-Object { [int](Zahl-Aus $_.Nummer.T) } | Sort-Object -Unique)
        $erste = $zahlen[0]; $letzte = $zahlen[$zahlen.Count - 1]
        $luecken = @($erste..$letzte | Where-Object { $zahlen -notcontains $_ })
        if ($luecken.Count -gt 0) {
            $liste = ($luecken | ForEach-Object { '{0:00}' -f $_ }) -join ', '
            $ersterRaum = $mitNummer | Sort-Object { [int](Zahl-Aus $_.Nummer.T) } | Select-Object -First 1
            $ergebnisse.Add((New-Result 'Raumnummern' $false '' "Die Raumnummern sind nicht lückenlos: Nummer $liste fehlt in der Reihenfolge." $ersterRaum.Nummer.X $ersterRaum.Nummer.Y))
        }
        foreach ($s in @($stempel | Where-Object { -not $_.Nummer })) {
            $raum = & $raumname $s; $p = & $pos $s
            $ergebnisse.Add((New-Result "Raum $raum" $false '' "Raum ${raum}: Raumnummer fehlt (andere Räume im Plan haben eine Nummer)." $p[0] $p[1]))
            [void]$gemeldet.Add($s)
        }
    }

    # 2. Raumhöhe (nur wenn angegeben)
    foreach ($s in $stempel) {
        $rh = $s.Felder['RH'].Wert
        if ($rh) {
            $z = Zahl-Aus $rh.T
            if ($z -lt 2.0 -or $z -gt 6.0) {
                $raum = & $raumname $s
                $ergebnisse.Add((New-Result "Raum $raum" $false $rh.T "Raum ${raum}: Raumhöhe (RH) $($rh.T) m ist unwahrscheinlich (erwartet 2,00 m bis 6,00 m)." $rh.X $rh.Y))
            }
        }
    }

    if (@($ergebnisse | Where-Object { -not $_.Ok }).Count -eq 0 -and $stempel.Count -gt 0) {
        $ergebnisse.Add((New-Result 'Werk-Raumstempel' $true "$($stempel.Count) Stempel" '' $null $null))
    }
    $ergebnisse | Sort-Object { $_.Ok }, Angabe
}

$script:Pruefungen += @{
    Id     = 'A4W'
    Name   = 'Werk-Raumstempel'
    Phasen = @('werk')
    Run    = { param($items) Get-A4WWerkRaumstempel $items }
}
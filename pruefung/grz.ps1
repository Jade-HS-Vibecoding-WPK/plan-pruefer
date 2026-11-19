<#
  Add-on GRZ-Prüfer (Experiment, 19.11.): Serverteil.

  Liest aus einem Grundriss (PDF) die Geschosse, die Raumflächen je Geschoss und, wenn der Plan
  Maßketten und ein Achsraster hat, das Gebäuderechteck (Breite mal Tiefe aus den Gesamtmaßen).
  Es gibt keine Online-Abfrage und keine Bindung an eine Stadt oder ein Bundesland: Grundstücksgröße, GRZ und
  Jahr des Bebauungsplans gibt das Team von Hand ein.

  Gerechnet wird im Browser (web/grz.js), Regeln nach der Arbeitshilfe GRZ/GFZ (Ordner grz-gfz/).
  Ohne diese Datei läuft der Planprüfer unverändert weiter (der Server lädt sie nur, wenn sie da ist).
#>


# Lageplan-Beschriftungen: Name in einer Zeile, darunter die Fläche ("Wohnhaus" / "118,39 m²").
# Der gemeinsame Flächenleser (raumstempel.ps1, für A3/A4) erlaubt höchstens 40 Punkt zwischen Zahl und "m²". Im Lageplan steht
# die Einheit weiter rechts (bis 55 Punkt), darum hier ein eigener, toleranterer Leser. Nur Namen aus dem Lageplan-Wortschatz
# (Haus, Garage, Terrasse, befestigte Fläche ...) zählen, damit Raumstempel eines Grundrisses nicht als Lageplan-Fläche gelten.
$script:GrzLageplanWort = '(?i)haus(?!wirtschaft)|geb[aä]ude|garage|carport|stellplatz|terrasse|balkon|loggia|befestigt|zufahrt|zuweg|einfahrt|\bwege?\b|pflaster|versiegelt|nebenanlage|schuppen|pool|bebaut'
function Get-GrzLageplanFlaechen($items) {
    $items = @($items)
    $erg = New-Object System.Collections.Generic.List[object]
    foreach ($n in @($items | Where-Object { $_.T -match '^\d{1,5}[.,]\d{1,2}$' })) {
        $e = $items | Where-Object { [math]::Abs($_.Y - $n.Y) -le 3 -and $_.X -gt $n.X -and ($_.X - $n.X) -le 90 -and $_.T -match '^m(\s*[²2])?$' } | Sort-Object X | Select-Object -First 1
        if (-not $e) { continue }
        if ($e.T -eq 'm') {
            $hoch = $items | Where-Object { $_.T -match '^[²2]$' -and $_.X -gt $e.X -and ($_.X - $e.X) -le 20 -and [math]::Abs($_.Y - $e.Y) -le 8 } | Select-Object -First 1
            if (-not $hoch) { continue }
        }
        # Beschriftung: die Zeile direkt über der Zahl (5 bis 40 Punkt), Wörter über oder neben der Zahl
        $kand = @($items | Where-Object { $_.T -match '[A-Za-zÄÖÜäöüß]{2,}' -and ($n.Y - $_.Y) -ge 5 -and ($n.Y - $_.Y) -le 40 -and $_.X -ge ($n.X - 60) -and $_.X -le ($n.X + 150) })
        if ($kand.Count -eq 0) { continue }
        $zeileY = ($kand | Measure-Object -Property Y -Maximum).Maximum
        $worte = @($kand | Where-Object { [math]::Abs($_.Y - $zeileY) -le 3 } | Sort-Object X)
        $name = ''
        foreach ($w in $worte) {
            # "Be" "festigte": kleine Bruchstücke mit Kleinbuchstaben davor zusammenziehen
            if ($name -and $w.T -cmatch '^[a-zäöüß]' -and ($name -split ' ')[-1].Length -le 3) { $name += $w.T } else { $name = ($name + ' ' + $w.T).Trim() }
        }
        if ($name -notmatch $script:GrzLageplanWort) { continue }
        $zahl = 0.0
        [void][double]::TryParse(($n.T -replace ',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$zahl)
        if ($zahl -gt 0) { $erg.Add(@{ name = $name; flaeche = $zahl }) }
    }
    @($erg.ToArray())
}

# Grundriss lesen: Geschosse mit Raumflächen (nur Zahlen mit Komma, wie beim Raumprogramm) und Gebäuderechteck
function Get-GrzGrundriss($items, [string]$pdfPfad) {
    $r = Get-RaumprogrammRaeume @($items)
    $geschosse = @($r.geschosse)
    $gruppen = @{}
    foreach ($rm in @($r.raeume)) {
        $g = if ($rm.geschoss) { [string]$rm.geschoss } else { '' }
        if (-not $gruppen.ContainsKey($g)) { $gruppen[$g] = New-Object System.Collections.Generic.List[object] }
        $gruppen[$g].Add(@{ name = [string]$rm.name; flaeche = [double]$rm.flaeche })
    }
    $liste = @(foreach ($k in $gruppen.Keys) { @{ name = $k; raeume = @($gruppen[$k].ToArray()) } })
    # Gebäuderechteck aus den Gesamtmaßen der Maßketten (braucht Achsraster, sonst nichts)
    $rechteck = $null
    try {
        if ($pdfPfad -and (Test-Path $pdfPfad) -and (Get-Command Get-A2Gesamtmasse -ErrorAction SilentlyContinue)) {
            $gm = Get-A2Gesamtmasse @($items) @(Get-PdfLinienCached $pdfPfad)
            if ($gm -and $gm.Breite -gt 0 -and $gm.Tiefe -gt 0) { $rechteck = @{ breite = [double]$gm.Breite; tiefe = [double]$gm.Tiefe } }
        }
    } catch { $rechteck = $null }
    @{ geschosse = $geschosse; gruppen = $liste; rechteck = $rechteck; flaechen = @(Get-GrzLageplanFlaechen $items) }
}

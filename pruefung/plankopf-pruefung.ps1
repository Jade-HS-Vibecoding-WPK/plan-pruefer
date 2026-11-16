<#
  Planprüfer, Stufe 1: Plankopf-Prüfung (feste Regeln, ohne KI)

  Prüft, ob die Pflichtangaben im Plankopf eines ArchiCAD-PDFs vorhanden sind:
  Projektname, Projektort (Straße, PLZ, Ort), Bauherr, Maßstab, Datum, Planer,
  Planbezeichnung, Plannummer.

  Aufruf:
    .\plankopf-pruefung.ps1 -Pdf "..\testplaene\01_einfamilienhaus_ok.pdf"
#>
param([string]$Pdf)

$script:Latin = [System.Text.Encoding]::GetEncoding(28591)
$script:Inv = [System.Globalization.CultureInfo]::InvariantCulture

# ---------------------------------------------------------------------------
# 1. Text mit Position aus dem PDF lesen
# ---------------------------------------------------------------------------

function ConvertFrom-PdfString([string]$raw) {
    $b = New-Object System.Collections.Generic.List[byte]
    $k = 0
    while ($k -lt $raw.Length) {
        $c = $raw[$k]
        if ($c -eq '\') {
            $k++; $d = $raw[$k]
            if ($d -match '[0-7]') {
                $oct = [string]$d
                while ($oct.Length -lt 3 -and ($k + 1) -lt $raw.Length -and $raw[$k + 1] -match '[0-7]') { $k++; $oct += $raw[$k] }
                $b.Add([Convert]::ToByte([Convert]::ToInt32($oct, 8) -band 255))
            } elseif ($d -eq 'n') { $b.Add(10) } elseif ($d -eq 'r') { $b.Add(13) } elseif ($d -eq 't') { $b.Add(9) }
            else { $b.Add([byte][char]$d) }
        } else { $b.Add([byte]$c) }
        $k++
    }
    $arr = $b.ToArray()
    if ($arr.Length % 2 -eq 0 -and $arr.Length -gt 0) { [System.Text.Encoding]::BigEndianUnicode.GetString($arr) }
    else { $script:Latin.GetString($arr) }
}

function Get-PdfTextItems([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = $script:Latin.GetString($bytes)
    $streamRx = [regex]'stream\r?\n'
    $tokRx = [regex]'(?<tm>(?:-?[\d.]+(?:e-?\d+)?\s+){5}-?[\d.]+(?:e-?\d+)?\s*Tm)|(?<td>-?[\d.]+(?:e-?\d+)?\s+-?[\d.]+(?:e-?\d+)?\s*T[dD])|(?<tj>\((?<s>(?:\\.|[^\\)])*)\)\s*Tj)'
    $pos = 0
    while ($true) {
        $m = $streamRx.Match($text, $pos)
        if (-not $m.Success) { break }
        $start = $m.Index + $m.Length
        $end = $text.IndexOf('endstream', $start)
        if ($end -lt 0) { break }
        $len = $end - $start
        $pos = $end + 9
        if ($len -lt 20) { continue }
        try {
            $ms = New-Object System.IO.MemoryStream(, $bytes[($start + 2)..($start + $len - 1)])
            $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            $s = $script:Latin.GetString($out.ToArray())
        } catch { continue }
        if ($s -notmatch 'BT') { continue }
        $a = 1.0; $d = 1.0; $x = 0.0; $y = 0.0
        foreach ($t in $tokRx.Matches($s)) {
            if ($t.Groups['tm'].Success) {
                $p = ($t.Groups['tm'].Value -replace 'Tm', '').Trim() -split '\s+'
                $a = [double]::Parse($p[0], $script:Inv); $d = [double]::Parse($p[3], $script:Inv)
                $x = [double]::Parse($p[4], $script:Inv); $y = [double]::Parse($p[5], $script:Inv)
            } elseif ($t.Groups['td'].Success) {
                $p = ($t.Groups['td'].Value -replace 'T[dD]', '').Trim() -split '\s+'
                $x += [double]::Parse($p[0], $script:Inv) * $a
                $y += [double]::Parse($p[1], $script:Inv) * $d
            } elseif ($t.Groups['tj'].Success) {
                $str = (ConvertFrom-PdfString $t.Groups['s'].Value).Trim()
                if ($str.Length -gt 0) {
                    [pscustomobject]@{ X = $x; Y = $y; T = $str }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Beschriftungen (Synonyme) und Hilfsfunktionen
# ---------------------------------------------------------------------------

# Jede Angabe kann in den Plankopf-Layouts unterschiedlich heißen.
$script:Labels = [ordered]@{
    Projektname = '^(baumaßnahme|bauvorhaben|projekt|projektbezeichnung|bauvorhaben)$'
    Bauherr     = '^(bauherr|bauherr/-in|bauherrin|bauherrschaft|auftraggeber)$'
    Projektort  = '^(bauort|projektort|baugrundstück|grundstück|standort)$'
    Planer      = '^(planer|planverfasser|planersteller|entwurfsverfasser|name/datum|name)$'
    Sonstige    = '^(maßstab|datum|bezeichnung|planbezeichnung|planname|plannr\.?|plannummer|projektnr\.?|index|änderung|bearb\.?|blattgröße|dateiname|architekt|logo)$'
}

function Get-NormalizedLabel([string]$s) {
    ($s.ToLowerInvariant() -replace '\s', '') -replace ':$', ''
}

# Findet alle Beschriftungen im Plan (auch wenn sie in mehrere Textstücke zerlegt sind, z. B. "Bau" + "ort")
function Find-Labels($items) {
    $found = New-Object System.Collections.Generic.List[object]
    $sorted = @($items | Sort-Object { [math]::Round($_.Y / 2) }, X)
    $n = $sorted.Count
    for ($i = 0; $i -lt $n; $i++) {
        for ($len = 1; $len -le 3; $len++) {
            if ($i + $len - 1 -ge $n) { break }
            $group = $sorted[$i..($i + $len - 1)]
            $sameRow = $true
            foreach ($g in $group) { if ([math]::Abs($g.Y - $group[0].Y) -gt 1.5) { $sameRow = $false } }
            if (-not $sameRow) { break }
            $norm = Get-NormalizedLabel (($group | ForEach-Object { $_.T }) -join '')
            # Ein Wort mitten in einem Satz ist keine Beschriftung: dann stehen viele Textstücke in derselben Zeile dicht daneben.
            $nachbarn = @($sorted | Where-Object {
                    [math]::Abs($_.Y - $group[0].Y) -le 1.5 -and [math]::Abs($_.X - $group[0].X) -le 120 -and ($group -notcontains $_)
                }).Count
            if ($nachbarn -gt 3) { continue }
            foreach ($key in $script:Labels.Keys) {
                if ($norm -match $script:Labels[$key]) {
                    $found.Add([pscustomobject]@{ Key = $key; Name = $norm; X = $group[0].X; Y = $group[0].Y; Items = $group })
                    break
                }
            }
        }
    }
    $found
}

# Zugehörigen Wert zu einer Beschriftung finden: rechts daneben (gleiche Zeile) oder darunter.
function Get-LabelValue($label, $allLabels, $items) {
    $labelItems = @($allLabels | ForEach-Object { $_.Items } | ForEach-Object { $_ })
    $isLabelPiece = { param($it) $labelItems -contains $it }

    # a) gleiche Zeile, rechts von der Beschriftung, bis zur nächsten Beschriftung
    $rowLabels = @($allLabels | Where-Object { [math]::Abs($_.Y - $label.Y) -le 1.5 -and $_.X -gt $label.X + 1 })
    $rightLimit = [double]::MaxValue
    if ($rowLabels.Count -gt 0) { $rightLimit = ($rowLabels | Measure-Object X -Minimum).Minimum }
    $labelRightEdge = ($label.Items | Measure-Object X -Maximum).Maximum
    $right = @($items | Where-Object {
            [math]::Abs($_.Y - $label.Y) -le 6 -and $_.X -gt $labelRightEdge + 4 -and $_.X -lt $rightLimit -and
            -not (& $isLabelPiece $_)
        })
    if ($right.Count -gt 0) {
        return (($right | Sort-Object X | ForEach-Object { $_.T }) -join ' ')
    }

    # b) darunter, in derselben Spalte, bis zur nächsten Beschriftung
    $below = @($allLabels | Where-Object { $_.Y -gt $label.Y + 1.5 -and [math]::Abs($_.X - $label.X) -le 40 })
    $bound = $label.Y + 100
    if ($below.Count -gt 0) { $bound = [math]::Min($bound, ($below | Measure-Object Y -Minimum).Minimum - 1) }
    $col = @($items | Where-Object {
            $_.Y -gt $label.Y + 6 -and $_.Y -lt $bound -and [math]::Abs($_.X - $label.X) -le 40 -and
            -not (& $isLabelPiece $_)
        })
    if ($col.Count -eq 0) { return '' }
    # ganze Zeilen übernehmen (auch Textstücke weiter rechts in derselben Zeile)
    $rows = @($col | ForEach-Object { [math]::Round($_.Y, 0) } | Sort-Object -Unique)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($r in $rows) {
        $line = @($items | Where-Object {
                [math]::Abs($_.Y - $r) -le 1.5 -and $_.X -ge $label.X - 40 -and $_.X -lt $rightLimit -and
                -not (& $isLabelPiece $_)
            } | Sort-Object X)
        if ($line.Count -gt 0) { $parts.Add((($line | ForEach-Object { $_.T }) -join ' ')) }
    }
    $parts -join ' | '
}

function New-Result($angabe, $ok, $wert, $detail) {
    [pscustomobject]@{ Angabe = $angabe; Ok = $ok; Wert = $wert; Detail = $detail }
}

# ---------------------------------------------------------------------------
# 3. Prüfregeln
# ---------------------------------------------------------------------------

$script:DateRx = '\b\d{1,2}\.\d{1,2}\.(\d{4}|\d{2})\b'
$script:StreetRx = '(?i)\b[\wäöüß\-]*(straße|strasse|weg|allee|platz|gasse|ring|damm|ufer|chaussee)\b|\b[\wäöüß\-]*str\.'

function Test-Plankopf([string]$Path) {
    $items = @(Get-PdfTextItems $Path)
    if ($items.Count -eq 0) {
        return @(New-Result 'PDF' $false '' 'Kein Text im PDF gefunden (gescannt oder Schrift in Linien umgewandelt).')
    }
    $labels = @(Find-Labels $items)
    $results = New-Object System.Collections.Generic.List[object]

    # Anker: die Beschriftung "Maßstab" (liegt immer im Plankopf); fehlt sie, dienen andere Beschriftungen als Ersatz.
    $anchor = $null
    foreach ($an in 'maßstab', 'bezeichnung', 'planname', 'name/datum', 'name', 'planverfasser', 'planersteller', 'datum') {
        $anchor = $labels | Where-Object { $_.Name -eq $an } | Select-Object -First 1
        if ($anchor) { break }
    }

    function Get-ValueByKey($key) {
        $hits = @($labels | Where-Object { $_.Key -eq $key })
        # Kommt dieselbe Beschriftung mehrfach vor (z. B. in einer Verteilerliste), zählt die, die dem Plankopf am nächsten liegt.
        if ($anchor -and $hits.Count -gt 1) {
            $hits = @($hits | Sort-Object { [math]::Sqrt([math]::Pow($_.X - $anchor.X, 2) + [math]::Pow($_.Y - $anchor.Y, 2)) })
        }
        foreach ($h in $hits) {
            $v = Get-LabelValue $h $labels $items
            if ($v -and $v.Trim().Length -gt 0) { return @{ Found = $true; Value = $v; Label = $h } }
        }
        return @{ Found = ($hits.Count -gt 0); Value = ''; Label = $null }
    }

    # Projektname
    $r = Get-ValueByKey 'Projektname'
    $name = $r.Value
    if (-not $name) {
        $kw = $items | Where-Object { $_.T -match '(?i)^(Neubau|Umbau|Anbau|Sanierung|Erweiterung|Einfamilienwohnhaus|Mehrfamilienhaus|Wohnhaus)\b' } | Select-Object -First 1
        if ($kw) {
            $line = @($items | Where-Object { [math]::Abs($_.Y - $kw.Y) -le 1.5 -and $_.X -ge $kw.X - 3 } | Sort-Object X | ForEach-Object { $_.T })
            $name = $line -join ' '
        }
    }
    $results.Add((New-Result 'Projektname' ([bool]$name) $name $(if ($name) { '' } else { 'Kein Projektname gefunden.' })))

    # Bauherr
    $r = Get-ValueByKey 'Bauherr'
    $bauherrValue = $r.Value
    $bauherrName = ($bauherrValue -replace $script:DateRx, '') -replace '[^A-Za-zÄÖÜäöüß]', ''
    $results.Add((New-Result 'Bauherr' ($bauherrName.Length -ge 2) $bauherrValue $(if ($bauherrName.Length -ge 2) { '' } else { 'Kein Bauherr gefunden.' })))

    # Projektort (Straße, PLZ, Ort)
    $r = Get-ValueByKey 'Projektort'
    $ortText = $r.Value
    if (-not $ortText) {
        # Layouts ohne Beschriftung "Bauort": Zeile mit Straßenname suchen, die nicht zum Bauherrn gehört
        $cand = @($items | Where-Object { $_.T -match $script:StreetRx -and $bauherrValue -notmatch [regex]::Escape($_.T) })
        foreach ($c in $cand) {
            $line = @($items | Where-Object { [math]::Abs($_.Y - $c.Y) -le 1.5 -and $_.X -ge $c.X - 3 } | Sort-Object X | ForEach-Object { $_.T })
            $ortText = $line -join ' '
            break
        }
    }
    $hasStreet = $ortText -match $script:StreetRx
    $hasPlz = $ortText -match '\b\d{5}\b'
    $rest = $ortText -replace $script:StreetRx, '' -replace '\b\d{5}\b', '' -replace '\b\d+[a-zA-Z]?\b', '' -replace '[^A-Za-zÄÖÜäöüß ]', ''
    $hasOrt = $rest.Trim().Length -ge 2
    $missing = @()
    if (-not $ortText) { $missing = @('Straße', 'Postleitzahl', 'Ort') }
    else {
        if (-not $hasStreet) { $missing += 'Straße' }
        if (-not $hasPlz) { $missing += 'Postleitzahl' }
        if (-not $hasOrt) { $missing += 'Ort' }
    }
    $results.Add((New-Result 'Projektort' ($missing.Count -eq 0) $ortText $(if ($missing.Count -eq 0) { '' } else { 'Fehlt: ' + ($missing -join ', ') })))

    # Maßstab
    $m = $items | Where-Object { $_.T -match '(?<!\d)1\s*:\s*\d{1,4}(?!\d)' } | Select-Object -First 1
    $results.Add((New-Result 'Maßstab' ([bool]$m) $(if ($m) { $m.T } else { '' }) $(if ($m) { '' } else { 'Kein Maßstab (z. B. 1:100) gefunden.' })))

    # Datum
    $dt = $items | Where-Object { $_.T -match $script:DateRx } | Select-Object -First 1
    $dtVal = ''
    if ($dt) { $dtVal = ([regex]::Match($dt.T, $script:DateRx)).Value }
    $results.Add((New-Result 'Datum' ([bool]$dt) $dtVal $(if ($dt) { '' } else { 'Kein Datum gefunden.' })))

    # Planer (Name, ohne Datum)
    $r = Get-ValueByKey 'Planer'
    $planerName = (($r.Value -replace $script:DateRx, '') -replace '[/|]', ' ').Trim()
    $planerLetters = $planerName -replace '[^A-Za-zÄÖÜäöüß]', ''
    $results.Add((New-Result 'Planer' ($planerLetters.Length -ge 2) $planerName $(if ($planerLetters.Length -ge 2) { '' } else { 'Kein Planer gefunden.' })))

    # Planbezeichnung (Name des Plans zum Einreichen, z. B. 03_Grundriss_EG_20260331_V1)
    $pb = $items | Where-Object { $_.T -match '^\d{2}_.+_V\d+$' } | Select-Object -First 1
    $results.Add((New-Result 'Planbezeichnung' ([bool]$pb) $(if ($pb) { $pb.T } else { '' }) $(if ($pb) { '' } else { 'Keine Planbezeichnung (z. B. 03_Grundriss_EG_20260331_V1) gefunden.' })))

    # Plannummer (z. B. G01, G02 ... oder eine einfache Zahl wie 2), in der Nähe von "Maßstab"
    $pn = $null
    if ($anchor) {
        $pn = $items | Where-Object {
            $_.T -match '^(G\d{2}|\d{1,2})$' -and ($_.X - $anchor.X) -ge -50 -and ($_.X - $anchor.X) -le 400 -and [math]::Abs($_.Y - $anchor.Y) -le 150
        } | Select-Object -First 1
    }
    $results.Add((New-Result 'Plannummer' ([bool]$pn) $(if ($pn) { $pn.T } else { '' }) $(if ($pn) { '' } else { 'Keine Plannummer (z. B. G01 oder 2) gefunden.' })))

    $results
}

# Wenn das Skript direkt aufgerufen wird: Ergebnis anzeigen
if ($Pdf) {
    $res = Test-Plankopf $Pdf
    Write-Host ""
    Write-Host "Prüfung: $(Split-Path $Pdf -Leaf)"
    Write-Host ("-" * 70)
    foreach ($x in $res) {
        $mark = if ($x.Ok) { '[ok]    ' } else { '[FEHLT] ' }
        $line = "{0}{1,-16} {2}" -f $mark, $x.Angabe, $x.Wert
        if ($x.Detail) { $line += "  -> " + $x.Detail }
        Write-Host $line
    }
    $bad = @($res | Where-Object { -not $_.Ok }).Count
    Write-Host ("-" * 70)
    Write-Host "$bad Befund(e)"
}

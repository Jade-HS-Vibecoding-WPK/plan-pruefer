<#
  PDF-Grafik: liest gefüllte Dreiecke (zum Beispiel die Blickrichtungs-Dreiecke an Schnittlinien) aus einem
  ArchiCAD-PDF. Die Dreiecke stehen im PDF als Vektorform mit Koordinaten, die Richtung lässt sich also genau
  berechnen, ohne KI.

  Get-PdfDreiecke liefert pro gefülltem Dreieck:
    P1, P2, P3   die drei Eckpunkte (X, Y) im selben Koordinatensystem wie die Textstücke aus pdf-text.ps1
    Mitte        Schwerpunkt (X, Y)
    Kante        längste Kantenlänge
    Richtung     'links', 'rechts', 'oben', 'unten' oder 'schräg' (Richtung der Spitze, siehe Get-DreieckRichtung)

  Das Koordinatensystem: Y wächst nach unten, wie bei den Textstücken (pdf-text.ps1).
#>

$script:GrafikInv = [System.Globalization.CultureInfo]::InvariantCulture

# Richtung eines (rechtwinklig angeordneten) Dreiecks: Zwei Eckpunkte haben dieselbe X- oder Y-Koordinate
# (die Grundseite liegt auf der Schnittlinie), der dritte Eckpunkt ist die Spitze.
function Get-DreieckRichtung($p) {
    $tol = 0.05
    for ($i = 0; $i -lt 3; $i++) {
        $a = $p[$i]; $b = $p[($i + 1) % 3]; $c = $p[($i + 2) % 3]
        if ([math]::Abs($a.X - $b.X) -le $tol -and [math]::Abs($c.X - $a.X) -gt 0.5) { if ($c.X -lt $a.X) { return 'links' } else { return 'rechts' } }
        if ([math]::Abs($a.Y - $b.Y) -le $tol -and [math]::Abs($c.Y - $a.Y) -gt 0.5) { if ($c.Y -lt $a.Y) { return 'oben' } else { return 'unten' } }
    }
    return 'schräg'
}

# Seitengröße des PDFs in Punkt (Breite, Höhe). Fehlt die Angabe, gilt A3 quer.
function Get-PdfSeitengroesse([string]$Path) {
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($Path))
    $mb = [regex]::Match($text, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+(?<w>[\d.]+)\s+(?<h>[\d.]+)\s*\]')
    if ($mb.Success) { return [pscustomobject]@{ Breite = [double]::Parse($mb.Groups['w'].Value, $script:GrafikInv); Hoehe = [double]::Parse($mb.Groups['h'].Value, $script:GrafikInv) } }
    [pscustomobject]@{ Breite = 1190.55; Hoehe = 841.89 }
}

function Get-PdfDreiecke([string]$Path, [double]$MinKante = 4, [double]$MaxKante = 60) {
    $latin = [System.Text.Encoding]::GetEncoding(28591)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = $latin.GetString($bytes)
    # Seitenhöhe: die Y-Achse der Pfade zeigt nach oben, die der Textstücke (pdf-text.ps1) nach unten. Wir richten sie gleich aus.
    $seitenHoehe = 841.89
    $mb = [regex]::Match($text, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+[\d.]+\s+(?<h>[\d.]+)\s*\]')
    if ($mb.Success) { $seitenHoehe = [double]::Parse($mb.Groups['h'].Value, $script:GrafikInv) }
    $streamRx = [regex]'stream\r?\n'
    # Zeichenketten und Namen werden übersprungen. Befehle stehen in diesem PDF ohne Leerzeichen hintereinander
    # (zum Beispiel "cmqq2.83465"), deshalb werden zusammenhängende Buchstaben anschließend in Befehle zerlegt.
    $tokRx = [regex]'(?<str>\((?:\\.|[^\\)])*\))|(?<hex><[0-9A-Fa-f\s]*>)|(?<name>/[^\s/\[\]()<>]*)|(?<num>-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?)|(?<op>[A-Za-z][A-Za-z*]*|[''"])'
    $bekannteOps = @('W*', 'f*', 'B*', 'b*', 'SCN', 'scn', 'BT', 'ET', 'cm', 're', 'gs', 'rg', 'RG', 'sc', 'SC', 'Tc', 'Tz', 'Tf', 'Tr', 'Tm', 'Td', 'TD', 'Tj', 'TJ', 'Tw', 'TL', 'T*', 'Do', 'sh', 'BI', 'ID', 'EI', 'ri', 'q', 'Q', 'm', 'l', 'c', 'v', 'y', 'h', 'f', 'F', 'S', 's', 'n', 'B', 'b', 'W', 'w', 'd', 'j', 'J', 'M', 'i', 'g', 'G', 'k', 'K')
    $pos = 0
    while ($true) {
        $m = $streamRx.Match($text, $pos)
        if (-not $m.Success) { break }
        $start = $m.Index + $m.Length
        $end = $text.IndexOf('endstream', $start)
        if ($end -lt 0) { break }
        $len = $end - $start
        $pos = $end + 9
        if ($len -lt 200) { continue }
        try {
            $ms = New-Object System.IO.MemoryStream(, $bytes[($start + 2)..($start + $len - 1)])
            $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            $s = $latin.GetString($out.ToArray())
        } catch { continue }
        if ($s.Length -lt 200 -or $s.IndexOf('f') -lt 0) { continue }
        $ctm = @(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        $fuell = @(0.0, 0.0, 0.0)
        $stack = New-Object System.Collections.Generic.Stack[object]
        $zahlen = New-Object System.Collections.Generic.List[double]
        $pfad = New-Object System.Collections.Generic.List[object]   # Punkte des aktuellen Teilpfads
        $teilpfade = 0; $kurve = $false

        # Befehlsfolge aufbauen: Zahlen und zerlegte Befehle in der Reihenfolge des Streams
        $folge = New-Object System.Collections.Generic.List[object]
        foreach ($t in $tokRx.Matches($s)) {
            if ($t.Groups['num'].Success) { $folge.Add([double]::Parse($t.Groups['num'].Value, $script:GrafikInv)); continue }
            if (-not $t.Groups['op'].Success) { continue }
            $rest = $t.Groups['op'].Value
            while ($rest.Length -gt 0) {
                $treffer = $null
                foreach ($o in $bekannteOps) { if ($rest.StartsWith($o, [System.StringComparison]::Ordinal)) { if ($null -eq $treffer -or $o.Length -gt $treffer.Length) { $treffer = $o } } }
                if ($null -eq $treffer) { $rest = $rest.Substring(1); continue }
                $folge.Add($treffer)
                $rest = $rest.Substring($treffer.Length)
            }
        }
        foreach ($element in $folge) {
            if ($element -is [double]) { $zahlen.Add($element); continue }
            $op = [string]$element
            switch -CaseSensitive ($op) {
                'q' { $stack.Push(@($ctm.Clone(), $fuell.Clone())) }
                'Q' { if ($stack.Count -gt 0) { $z = $stack.Pop(); $ctm = $z[0]; $fuell = $z[1] } }
                'rg' { if ($zahlen.Count -ge 3) { $fuell = @($zahlen[$zahlen.Count - 3], $zahlen[$zahlen.Count - 2], $zahlen[$zahlen.Count - 1]) } }
                'g' { if ($zahlen.Count -ge 1) { $gr = $zahlen[$zahlen.Count - 1]; $fuell = @($gr, $gr, $gr) } }
                'cm' {
                    if ($zahlen.Count -ge 6) {
                        $n = $zahlen.GetRange($zahlen.Count - 6, 6)
                        $a = $n[0]; $b = $n[1]; $c = $n[2]; $d = $n[3]; $e = $n[4]; $f = $n[5]
                        # neue Matrix = n x ctm
                        $ctm = @(
                            ($a * $ctm[0] + $b * $ctm[2]), ($a * $ctm[1] + $b * $ctm[3]),
                            ($c * $ctm[0] + $d * $ctm[2]), ($c * $ctm[1] + $d * $ctm[3]),
                            ($e * $ctm[0] + $f * $ctm[2] + $ctm[4]), ($e * $ctm[1] + $f * $ctm[3] + $ctm[5])
                        )
                    }
                }
                'm' {
                    if ($zahlen.Count -ge 2) {
                        $x = $zahlen[$zahlen.Count - 2]; $y = $zahlen[$zahlen.Count - 1]
                        $pfad.Clear(); $kurve = $false; $teilpfade = 1
                        $pfad.Add([pscustomobject]@{ X = $ctm[0] * $x + $ctm[2] * $y + $ctm[4]; Y = $ctm[1] * $x + $ctm[3] * $y + $ctm[5] })
                    }
                }
                'l' {
                    if ($zahlen.Count -ge 2) {
                        $x = $zahlen[$zahlen.Count - 2]; $y = $zahlen[$zahlen.Count - 1]
                        $pfad.Add([pscustomobject]@{ X = $ctm[0] * $x + $ctm[2] * $y + $ctm[4]; Y = $ctm[1] * $x + $ctm[3] * $y + $ctm[5] })
                    }
                }
                { $_ -cin 'c', 'v', 'y', 're' } { $kurve = $true }
                { $_ -cin 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*' } {
                    if (-not $kurve -and $teilpfade -eq 1) {
                        $pt = $pfad.ToArray()
                        # geschlossenes Dreieck: letzter Punkt gleich erster
                        if ($pt.Length -eq 4 -and [math]::Abs($pt[3].X - $pt[0].X) -lt 0.01 -and [math]::Abs($pt[3].Y - $pt[0].Y) -lt 0.01) { $pt = $pt[0..2] }
                        if ($pt.Length -eq 3) {
                            $pt = @($pt | ForEach-Object { [pscustomobject]@{ X = $_.X; Y = $seitenHoehe - $_.Y } })
                            $k1 = [math]::Sqrt([math]::Pow($pt[0].X - $pt[1].X, 2) + [math]::Pow($pt[0].Y - $pt[1].Y, 2))
                            $k2 = [math]::Sqrt([math]::Pow($pt[1].X - $pt[2].X, 2) + [math]::Pow($pt[1].Y - $pt[2].Y, 2))
                            $k3 = [math]::Sqrt([math]::Pow($pt[2].X - $pt[0].X, 2) + [math]::Pow($pt[2].Y - $pt[0].Y, 2))
                            $kante = [math]::Max($k1, [math]::Max($k2, $k3))
                            if ($kante -ge $MinKante -and $kante -le $MaxKante) {
                                [pscustomobject]@{
                                    P1 = $pt[0]; P2 = $pt[1]; P3 = $pt[2]
                                    Mitte = [pscustomobject]@{ X = ($pt[0].X + $pt[1].X + $pt[2].X) / 3; Y = ($pt[0].Y + $pt[1].Y + $pt[2].Y) / 3 }
                                    Kante = $kante
                                    Richtung = (Get-DreieckRichtung $pt)
                                    Farbe = [pscustomobject]@{ R = $fuell[0]; G = $fuell[1]; B = $fuell[2] }
                                }
                            }
                        }
                    }
                    $pfad.Clear(); $teilpfade = 0; $kurve = $false
                }
                { $_ -cin 'S', 's', 'n' } { $pfad.Clear(); $teilpfade = 0; $kurve = $false }
                'h' { }
                default { }
            }
            $zahlen.Clear()
        }
    }
}

# Gerade Linien (Striche mit zwei Punkten) aus dem PDF. Gestrichelte und Strichpunkt-Linien stehen in ArchiCAD-PDFs
# als viele einzelne kurze Striche. Liefert pro Strich: X1, Y1, X2, Y2 (Koordinaten wie bei den Textstücken, Y nach unten)
# und Laenge. Nur Striche ab MinLaenge werden geliefert, Punkte der Strichpunkt-Linie (Länge fast 0) zählen mit MinLaenge 0.
function Get-PdfLinien([string]$Path, [double]$MinLaenge = 0) {
    $latin = [System.Text.Encoding]::GetEncoding(28591)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = $latin.GetString($bytes)
    $seitenHoehe = 841.89
    $mb = [regex]::Match($text, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+[\d.]+\s+(?<h>[\d.]+)\s*\]')
    if ($mb.Success) { $seitenHoehe = [double]::Parse($mb.Groups['h'].Value, $script:GrafikInv) }
    $streamRx = [regex]'stream\r?\n'
    $tokRx = [regex]'(?<str>\((?:\\.|[^\\)])*\))|(?<hex><[0-9A-Fa-f\s]*>)|(?<name>/[^\s/\[\]()<>]*)|(?<num>-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?)|(?<op>[A-Za-z][A-Za-z*]*|[''"])'
    $bekannteOps = @('W*', 'f*', 'B*', 'b*', 'SCN', 'scn', 'BT', 'ET', 'cm', 're', 'gs', 'rg', 'RG', 'sc', 'SC', 'Tc', 'Tz', 'Tf', 'Tr', 'Tm', 'Td', 'TD', 'Tj', 'TJ', 'Tw', 'TL', 'T*', 'Do', 'sh', 'BI', 'ID', 'EI', 'ri', 'q', 'Q', 'm', 'l', 'c', 'v', 'y', 'h', 'f', 'F', 'S', 's', 'n', 'B', 'b', 'W', 'w', 'd', 'j', 'J', 'M', 'i', 'g', 'G', 'k', 'K')
    $pos = 0
    while ($true) {
        $m = $streamRx.Match($text, $pos)
        if (-not $m.Success) { break }
        $start = $m.Index + $m.Length
        $end = $text.IndexOf('endstream', $start)
        if ($end -lt 0) { break }
        $len = $end - $start
        $pos = $end + 9
        if ($len -lt 200) { continue }
        try {
            $ms = New-Object System.IO.MemoryStream(, $bytes[($start + 2)..($start + $len - 1)])
            $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            $s = $latin.GetString($out.ToArray())
        } catch { continue }
        if ($s.Length -lt 200 -or $s.IndexOf(' m') -lt 0) { continue }
        $ctm = @(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        $stack = New-Object System.Collections.Generic.Stack[object]
        $zahlen = New-Object System.Collections.Generic.List[double]
        $pfad = New-Object System.Collections.Generic.List[object]
        $kurve = $false
        $folge = New-Object System.Collections.Generic.List[object]
        foreach ($t in $tokRx.Matches($s)) {
            if ($t.Groups['num'].Success) { $folge.Add([double]::Parse($t.Groups['num'].Value, $script:GrafikInv)); continue }
            if (-not $t.Groups['op'].Success) { continue }
            $rest = $t.Groups['op'].Value
            while ($rest.Length -gt 0) {
                $treffer = $null
                foreach ($o in $bekannteOps) { if ($rest.StartsWith($o, [System.StringComparison]::Ordinal)) { if ($null -eq $treffer -or $o.Length -gt $treffer.Length) { $treffer = $o } } }
                if ($null -eq $treffer) { $rest = $rest.Substring(1); continue }
                $folge.Add($treffer)
                $rest = $rest.Substring($treffer.Length)
            }
        }
        foreach ($element in $folge) {
            if ($element -is [double]) { $zahlen.Add($element); continue }
            $op = [string]$element
            switch -CaseSensitive ($op) {
                'q' { $stack.Push($ctm.Clone()) }
                'Q' { if ($stack.Count -gt 0) { $ctm = $stack.Pop() } }
                'cm' {
                    if ($zahlen.Count -ge 6) {
                        $n = $zahlen.GetRange($zahlen.Count - 6, 6)
                        $a = $n[0]; $b = $n[1]; $c = $n[2]; $d = $n[3]; $e = $n[4]; $f = $n[5]
                        $ctm = @(
                            ($a * $ctm[0] + $b * $ctm[2]), ($a * $ctm[1] + $b * $ctm[3]),
                            ($c * $ctm[0] + $d * $ctm[2]), ($c * $ctm[1] + $d * $ctm[3]),
                            ($e * $ctm[0] + $f * $ctm[2] + $ctm[4]), ($e * $ctm[1] + $f * $ctm[3] + $ctm[5])
                        )
                    }
                }
                'm' {
                    if ($zahlen.Count -ge 2) {
                        $x = $zahlen[$zahlen.Count - 2]; $y = $zahlen[$zahlen.Count - 1]
                        $pfad.Clear(); $kurve = $false
                        $pfad.Add([pscustomobject]@{ X = $ctm[0] * $x + $ctm[2] * $y + $ctm[4]; Y = $ctm[1] * $x + $ctm[3] * $y + $ctm[5] })
                    }
                }
                'l' {
                    if ($zahlen.Count -ge 2) {
                        $x = $zahlen[$zahlen.Count - 2]; $y = $zahlen[$zahlen.Count - 1]
                        $pfad.Add([pscustomobject]@{ X = $ctm[0] * $x + $ctm[2] * $y + $ctm[4]; Y = $ctm[1] * $x + $ctm[3] * $y + $ctm[5] })
                    }
                }
                { $_ -cin 'c', 'v', 'y', 're' } { $kurve = $true }
                { $_ -cin 'S', 's' } {
                    if (-not $kurve -and $pfad.Count -eq 2) {
                        $dx = $pfad[1].X - $pfad[0].X; $dy = $pfad[1].Y - $pfad[0].Y
                        $laenge = [math]::Sqrt($dx * $dx + $dy * $dy)
                        if ($laenge -ge $MinLaenge) {
                            [pscustomobject]@{ X1 = $pfad[0].X; Y1 = $seitenHoehe - $pfad[0].Y; X2 = $pfad[1].X; Y2 = $seitenHoehe - $pfad[1].Y; Laenge = $laenge }
                        }
                    }
                    $pfad.Clear(); $kurve = $false
                }
                { $_ -cin 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*', 'n' } { $pfad.Clear(); $kurve = $false }
                default { }
            }
            $zahlen.Clear()
        }
    }
}



# Kleine gezeichnete Formen (Pfade) aus dem PDF: Pfeile, Dreiecke, Türbögen und ähnliches.
# Liefert pro Pfad: Teile (Liste von Punktfolgen, Koordinaten wie bei den Textstücken, Y nach unten), Art ('fuellen', 'strich'
# oder 'beides'), Kurve ($true, wenn Bögen im Pfad sind), Farbe (Füllfarbe R, G, B), X0, Y0, X1, Y1 (Umfassungsrechteck).
# Nur Pfade, die höchstens MaxBreite Punkt breit und hoch sind (große Wandflächen werden nicht geliefert).
# Mit -NurKurven werden nur Pfade mit Bögen geliefert (viel schneller, reicht für Türbögen).
function Get-PdfPfade([string]$Path, [double]$MaxBreite = 80, [switch]$NurKurven, [switch]$MitLinien) {
    $latin = [System.Text.Encoding]::GetEncoding(28591)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = $latin.GetString($bytes)
    $seitenHoehe = 841.89
    $mb = [regex]::Match($text, '/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+[\d.]+\s+(?<h>[\d.]+)\s*\]')
    if ($mb.Success) { $seitenHoehe = [double]::Parse($mb.Groups['h'].Value, $script:GrafikInv) }
    $streamRx = [regex]'stream\r?\n'
    $tokRx = [regex]'(?<str>\((?:\\.|[^\\)])*\))|(?<hex><[0-9A-Fa-f\s]*>)|(?<name>/[^\s/\[\]()<>]*)|(?<num>-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?)|(?<op>[A-Za-z][A-Za-z*]*|[''"])'
    $bekannteOps = @('W*', 'f*', 'B*', 'b*', 'SCN', 'scn', 'BT', 'ET', 'cm', 're', 'gs', 'rg', 'RG', 'sc', 'SC', 'Tc', 'Tz', 'Tf', 'Tr', 'Tm', 'Td', 'TD', 'Tj', 'TJ', 'Tw', 'TL', 'T*', 'Do', 'sh', 'BI', 'ID', 'EI', 'ri', 'q', 'Q', 'm', 'l', 'c', 'v', 'y', 'h', 'f', 'F', 'S', 's', 'n', 'B', 'b', 'W', 'w', 'd', 'j', 'J', 'M', 'i', 'g', 'G', 'k', 'K')
    $pos = 0
    while ($true) {
        $m = $streamRx.Match($text, $pos)
        if (-not $m.Success) { break }
        $start = $m.Index + $m.Length
        $end = $text.IndexOf('endstream', $start)
        if ($end -lt 0) { break }
        $len = $end - $start
        $pos = $end + 9
        if ($len -lt 100) { continue }
        try {
            $ms = New-Object System.IO.MemoryStream(, $bytes[($start + 2)..($start + $len - 1)])
            $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            $s = $latin.GetString($out.ToArray())
        } catch { continue }
        if ($s.Length -lt 100 -or $s.IndexOf(' m') -lt 0) { continue }
        $ctm = @(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
        $fuell = @(0.0, 0.0, 0.0)
        $stack = New-Object System.Collections.Generic.Stack[object]
        $zahlen = New-Object System.Collections.Generic.List[double]
        $teile = New-Object System.Collections.Generic.List[object]
        $akt = $null; $kurve = $false
        $folge = New-Object System.Collections.Generic.List[object]
        foreach ($t in $tokRx.Matches($s)) {
            if ($t.Groups['num'].Success) { $folge.Add([double]::Parse($t.Groups['num'].Value, $script:GrafikInv)); continue }
            if (-not $t.Groups['op'].Success) { continue }
            $rest = $t.Groups['op'].Value
            while ($rest.Length -gt 0) {
                $treffer = $null
                foreach ($o in $bekannteOps) { if ($rest.StartsWith($o, [System.StringComparison]::Ordinal)) { if ($null -eq $treffer -or $o.Length -gt $treffer.Length) { $treffer = $o } } }
                if ($null -eq $treffer) { $rest = $rest.Substring(1); continue }
                $folge.Add($treffer)
                $rest = $rest.Substring($treffer.Length)
            }
        }
        $punkt = { param($x, $y) [pscustomobject]@{ X = $ctm[0] * $x + $ctm[2] * $y + $ctm[4]; Y = $seitenHoehe - ($ctm[1] * $x + $ctm[3] * $y + $ctm[5]) } }
        foreach ($element in $folge) {
            if ($element -is [double]) { $zahlen.Add($element); continue }
            $op = [string]$element
            switch -CaseSensitive ($op) {
                'q' { $stack.Push(@($ctm.Clone(), $fuell.Clone())) }
                'Q' { if ($stack.Count -gt 0) { $z = $stack.Pop(); $ctm = $z[0]; $fuell = $z[1] } }
                'rg' { if ($zahlen.Count -ge 3) { $fuell = @($zahlen[$zahlen.Count - 3], $zahlen[$zahlen.Count - 2], $zahlen[$zahlen.Count - 1]) } }
                'g' { if ($zahlen.Count -ge 1) { $gr = $zahlen[$zahlen.Count - 1]; $fuell = @($gr, $gr, $gr) } }
                'cm' {
                    if ($zahlen.Count -ge 6) {
                        $n = $zahlen.GetRange($zahlen.Count - 6, 6)
                        $a = $n[0]; $b = $n[1]; $c = $n[2]; $d = $n[3]; $e = $n[4]; $f = $n[5]
                        $ctm = @(
                            ($a * $ctm[0] + $b * $ctm[2]), ($a * $ctm[1] + $b * $ctm[3]),
                            ($c * $ctm[0] + $d * $ctm[2]), ($c * $ctm[1] + $d * $ctm[3]),
                            ($e * $ctm[0] + $f * $ctm[2] + $ctm[4]), ($e * $ctm[1] + $f * $ctm[3] + $ctm[5])
                        )
                    }
                }
                'm' { if ($zahlen.Count -ge 2) { $akt = New-Object System.Collections.Generic.List[object]; $akt.Add([pscustomobject]@{ X = $ctm[0] * $zahlen[$zahlen.Count - 2] + $ctm[2] * $zahlen[$zahlen.Count - 1] + $ctm[4]; Y = $seitenHoehe - ($ctm[1] * $zahlen[$zahlen.Count - 2] + $ctm[3] * $zahlen[$zahlen.Count - 1] + $ctm[5]) }); $teile.Add($akt) } }
                'l' { if ($zahlen.Count -ge 2 -and $akt) { $akt.Add([pscustomobject]@{ X = $ctm[0] * $zahlen[$zahlen.Count - 2] + $ctm[2] * $zahlen[$zahlen.Count - 1] + $ctm[4]; Y = $seitenHoehe - ($ctm[1] * $zahlen[$zahlen.Count - 2] + $ctm[3] * $zahlen[$zahlen.Count - 1] + $ctm[5]) }) } }
                { $_ -cin 'c', 'v', 'y' } { $kurve = $true; if ($zahlen.Count -ge 2 -and $akt) { $akt.Add([pscustomobject]@{ X = $ctm[0] * $zahlen[$zahlen.Count - 2] + $ctm[2] * $zahlen[$zahlen.Count - 1] + $ctm[4]; Y = $seitenHoehe - ($ctm[1] * $zahlen[$zahlen.Count - 2] + $ctm[3] * $zahlen[$zahlen.Count - 1] + $ctm[5]) }) } }
                're' {
                    if ($zahlen.Count -ge 4) {
                        $x = $zahlen[$zahlen.Count - 4]; $y = $zahlen[$zahlen.Count - 3]; $w = $zahlen[$zahlen.Count - 2]; $h = $zahlen[$zahlen.Count - 1]
                        $akt = New-Object System.Collections.Generic.List[object]
                        foreach ($q in @(@($x, $y), @(($x + $w), $y), @(($x + $w), ($y + $h)), @($x, ($y + $h)))) { $akt.Add((& $punkt $q[0] $q[1])) }
                        $teile.Add($akt)
                    }
                }
                { $_ -cin 'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*' } {
                    # Mit -MitLinien zusätzlich jeden geraden Strich aus zwei Punkten liefern (jede Länge), Typ = 'Linie'
                    if ($MitLinien -and ($op -ceq 'S' -or $op -ceq 's') -and -not $kurve -and $teile.Count -eq 1 -and $teile[0].Count -eq 2) {
                        $pa = $teile[0][0]; $pb = $teile[0][1]
                        [pscustomobject]@{ Typ = 'Linie'; X1 = $pa.X; Y1 = $pa.Y; X2 = $pb.X; Y2 = $pb.Y; Laenge = [math]::Sqrt(($pb.X - $pa.X) * ($pb.X - $pa.X) + ($pb.Y - $pa.Y) * ($pb.Y - $pa.Y)) }
                    }
                    if ($teile.Count -gt 0 -and (-not $NurKurven -or $kurve)) {
                        $x0 = [double]::MaxValue; $x1 = [double]::MinValue; $y0 = [double]::MaxValue; $y1 = [double]::MinValue
                        foreach ($tp in $teile) { foreach ($q in $tp) { if ($q.X -lt $x0) { $x0 = $q.X }; if ($q.X -gt $x1) { $x1 = $q.X }; if ($q.Y -lt $y0) { $y0 = $q.Y }; if ($q.Y -gt $y1) { $y1 = $q.Y } } }
                        if (($x1 - $x0) -le $MaxBreite -and ($y1 - $y0) -le $MaxBreite) {
                            $art = if ($op -cin 'S', 's') { 'strich' } elseif ($op -cin 'f', 'F', 'f*') { 'fuellen' } else { 'beides' }
                            [pscustomobject]@{
                                Typ = 'Pfad'; Teile = @($teile | ForEach-Object { , @($_.ToArray()) }); Art = $art; Kurve = $kurve
                                Farbe = [pscustomobject]@{ R = $fuell[0]; G = $fuell[1]; B = $fuell[2] }
                                X0 = $x0; Y0 = $y0; X1 = $x1; Y1 = $y1
                            }
                        }
                    }
                    $teile.Clear(); $akt = $null; $kurve = $false
                }
                'n' { $teile.Clear(); $akt = $null; $kurve = $false }
                default { }
            }
            $zahlen.Clear()
        }
    }
}

# Ein einziger Lesedurchgang pro PDF für alle Grafik-Prüfungen (A2, A2M, A5, A6, A8, A9): Linien, kleine Pfade und
# gefüllte Dreiecke kommen aus demselben Durchgang und werden für dieselbe Datei gemerkt. Das spart viel Zeit.
$script:GrafikCache = @{}
function Get-PdfGrafikCached([string]$Path) {
    $schluessel = "$Path|$((Get-Item $Path).LastWriteTimeUtc.Ticks)|$((Get-Item $Path).Length)"
    if (-not $script:GrafikCache.ContainsKey($schluessel)) {
        $alle = @(Get-PdfPfade $Path 60 -MitLinien)
        $linien = @($alle | Where-Object { $_.Typ -eq 'Linie' })
        $pfade = @($alle | Where-Object { $_.Typ -eq 'Pfad' })
        $script:GrafikCache = @{}
        $script:GrafikCache[$schluessel] = [pscustomobject]@{ Linien = $linien; Pfade = $pfade; Dreiecke = @(ConvertTo-Dreiecke $pfade) }
    }
    $script:GrafikCache[$schluessel]
}

# Gefüllte Dreiecke aus den Pfaden (wie Get-PdfDreiecke): ein Teilpfad mit 3 Punkten (oder 4, wenn der letzte gleich dem ersten ist), ohne Bögen.
function ConvertTo-Dreiecke($pfade, [double]$MinKante = 4, [double]$MaxKante = 60) {
    foreach ($p in $pfade) {
        if ($p.Kurve -or $p.Art -eq 'strich' -or $p.Teile.Count -ne 1) { continue }
        $pt = @($p.Teile[0])
        if ($pt.Count -eq 4 -and [math]::Abs($pt[3].X - $pt[0].X) -lt 0.01 -and [math]::Abs($pt[3].Y - $pt[0].Y) -lt 0.01) { $pt = $pt[0..2] }
        if ($pt.Count -ne 3) { continue }
        $k1 = [math]::Sqrt([math]::Pow($pt[0].X - $pt[1].X, 2) + [math]::Pow($pt[0].Y - $pt[1].Y, 2))
        $k2 = [math]::Sqrt([math]::Pow($pt[1].X - $pt[2].X, 2) + [math]::Pow($pt[1].Y - $pt[2].Y, 2))
        $k3 = [math]::Sqrt([math]::Pow($pt[2].X - $pt[0].X, 2) + [math]::Pow($pt[2].Y - $pt[0].Y, 2))
        $kante = [math]::Max($k1, [math]::Max($k2, $k3))
        if ($kante -lt $MinKante -or $kante -gt $MaxKante) { continue }
        [pscustomobject]@{
            P1 = $pt[0]; P2 = $pt[1]; P3 = $pt[2]
            Mitte = [pscustomobject]@{ X = ($pt[0].X + $pt[1].X + $pt[2].X) / 3; Y = ($pt[0].Y + $pt[1].Y + $pt[2].Y) / 3 }
            Kante = $kante
            Richtung = (Get-DreieckRichtung $pt)
            Farbe = $p.Farbe
        }
    }
}

function Get-PdfLinienCached([string]$Path) { (Get-PdfGrafikCached $Path).Linien }
function Get-PdfPfadeCached([string]$Path) { (Get-PdfGrafikCached $Path).Pfade }
function Get-PdfDreieckeCached([string]$Path) { (Get-PdfGrafikCached $Path).Dreiecke }

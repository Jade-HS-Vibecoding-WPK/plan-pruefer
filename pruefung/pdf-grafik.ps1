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
                'q' { $stack.Push($ctm.Clone()) }
                'Q' { if ($stack.Count -gt 0) { $ctm = $stack.Pop() } }
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

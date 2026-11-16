<#
  PDF-Leser: liest den Text eines ArchiCAD-PDFs mit Position (X, Y) aus.
  Wird von allen Prüfungen gemeinsam genutzt (per Punkt-Schreibweise eingebunden: . .\pdf-text.ps1).

  Ergebnis von Get-PdfTextItems: eine Liste von Textstücken mit
    X, Y  Position im Plan (Y wächst nach unten)
    T     der Text
#>

$script:Latin = [System.Text.Encoding]::GetEncoding(28591)
$script:Inv = [System.Globalization.CultureInfo]::InvariantCulture

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

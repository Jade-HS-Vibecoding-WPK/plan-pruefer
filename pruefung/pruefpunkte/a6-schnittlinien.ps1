<#
  A6 Schnittlinien (ohne KI, aus Text und Vektorgeometrie des PDFs)

  Eine Schnittlinie ist eine Strich-Punkt-Linie mit zwei ausgefüllten Dreiecken an den Enden, die in dieselbe
  Richtung zeigen (Blickrichtung). Eine Beschriftung mit Buchstaben ist möglich, aber nicht nötig.

  Die Dreiecke stehen im PDF als Vektorformen mit Koordinaten (siehe pdf-grafik.ps1). Ihre Richtung lässt sich
  deshalb genau berechnen, ohne KI. Die Buchstaben stehen als Text im PDF (siehe pdf-text.ps1).

  Geprüft wird:
    1. Es gibt mindestens eine Schnittlinie: zwei große Dreiecke gleicher Größe weit voneinander entfernt auf einer
       Linie (senkrecht oder waagerecht), oder zwei gleiche Buchstaben, die eine Schnittbezeichnung bilden.
    2. An beiden Enden steht ein Dreieck (sonst "Dreieck fehlt").
    3. Beide Dreiecke zeigen in dieselbe Richtung.
    4. Hat die Linie Buchstaben, dann an beiden Enden derselbe. Eine Linie ganz ohne Buchstaben ist in Ordnung.

  Grenzen:
    - Es werden nur senkrechte und waagerechte Schnittlinien mit rechtwinklig angeordneten Dreiecken erkannt.
    - Als Schnitt-Dreieck zählt eine Kantenlänge ab 8 Punkt, und es muss ALLEIN stehen: Dreiecke in Schraffuren
      (zum Beispiel Dämmung im Werkplan) liegen dicht beieinander und werden ignoriert.
    - Buchstaben allein zählen nie als Schnitt. Im Werkplan tragen auch Achsen gleiche Buchstaben an beiden Enden.
      Ein Buchstabe wird nur beachtet, wenn er neben einem Schnitt-Dreieck steht.
#>

$script:A6_DreieckMinKante = 8      # Mindestkantenlänge eines Schnitt-Dreiecks (Punkt im PDF)
$script:A6_DreieckMaxKante = 20     # Obergrenze, größere Dreiecke (Eingangspfeil) sind keine Schnitt-Dreiecke
$script:A6_MinAbstand = 100         # Mindestabstand der beiden Enden (Punkt)
$script:A6_Linientoleranz = 8       # so genau müssen die beiden Enden auf einer Linie liegen
$script:A6_BuchstabenNaehe = 45     # so nah muss ein Buchstabe an einem Dreieck stehen, um dazuzugehören
$script:A6_Einzeln = 30             # so weit muss ein Schnitt-Dreieck von anderen großen Dreiecken entfernt sein (sonst Schraffur)

function Get-A6Abstand($a, $b) { [math]::Sqrt([math]::Pow($a.X - $b.X, 2) + [math]::Pow($a.Y - $b.Y, 2)) }

function Test-A6AufLinie($a, $b) {
    $dx = [math]::Abs($a.X - $b.X); $dy = [math]::Abs($a.Y - $b.Y)
    $weit = [math]::Sqrt($dx * $dx + $dy * $dy) -ge $script:A6_MinAbstand
    $weit -and (($dx -le $script:A6_Linientoleranz) -or ($dy -le $script:A6_Linientoleranz))
}

# Reine Auswertung (ohne Dateizugriff), damit sie mit nachgestellten Daten getestet werden kann.
#   $items     Textstücke des Plans
#   $dreiecke  gefüllte Dreiecke des Plans (Get-PdfDreiecke)
function Get-A6Pruefung($items, $dreiecke) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]

    # Große Dreiecke zu Paaren verbinden
    # Nicht zu klein (Maßketten) und nicht zu groß (zum Beispiel der Eingangspfeil mit etwa 28 Punkt)
    $alleGross = @($dreiecke | Where-Object { $_.Kante -ge $script:A6_DreieckMinKante -and $_.Kante -le $script:A6_DreieckMaxKante })
    # Dreiecke in Schraffuren liegen dicht beieinander. Ein Schnitt-Dreieck steht allein.
    $gross = @($alleGross | Where-Object { $d = $_; @($alleGross | Where-Object { $_ -ne $d -and (Get-A6Abstand $_.Mitte $d.Mitte) -le $script:A6_Einzeln }).Count -eq 0 })
    $benutzt = New-Object System.Collections.Generic.HashSet[object]
    $paare = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $gross.Count; $i++) {
        if ($benutzt.Contains($gross[$i])) { continue }
        for ($j = $i + 1; $j -lt $gross.Count; $j++) {
            if ($benutzt.Contains($gross[$j])) { continue }
            $gleichGross = [math]::Abs($gross[$i].Kante - $gross[$j].Kante) -le (0.15 * $gross[$i].Kante)
            if ($gleichGross -and (Test-A6AufLinie $gross[$i].Mitte $gross[$j].Mitte)) {
                [void]$benutzt.Add($gross[$i]); [void]$benutzt.Add($gross[$j])
                $paare.Add(@{ A = $gross[$i]; B = $gross[$j] })
                break
            }
        }
    }

    # Buchstaben: einzelne Großbuchstaben (ein einzelnes N ist der Nordpfeil)
    # Ein Buchstabe, an den in derselben Zeile direkt ein weiteres Textstück anschließt, gehört zu einem Wort
    # (zum Beispiel "V" "K" "Fundament" = VK Fundament) und ist kein Schnittbuchstabe
    $buchstaben = @($items | Where-Object {
            $b = $_
            $b.T -cmatch '^[A-Z]$' -and -not @($items | Where-Object { $_ -ne $b -and [math]::Abs($_.Y - $b.Y) -le 1.5 -and ($_.X - $b.X) -gt 0 -and ($_.X - $b.X) -le 9 }).Count
        })
    $nCount = @($buchstaben | Where-Object { $_.T -ceq 'N' }).Count
    $buchstaben = @($buchstaben | Where-Object { -not ($_.T -ceq 'N' -and $nCount -eq 1) })
    $buchstabeVerwendet = New-Object System.Collections.Generic.HashSet[object]

    function Get-NaechsterBuchstabe($punkt) {
        $buchstaben | Where-Object { (Get-A6Abstand $_ $punkt) -le $script:A6_BuchstabenNaehe } | Sort-Object { Get-A6Abstand $_ $punkt } | Select-Object -First 1
    }

    # 1. Schnitte aus Dreieckspaaren
    foreach ($p in $paare) {
        $bA = Get-NaechsterBuchstabe $p.A.Mitte
        $bB = Get-NaechsterBuchstabe $p.B.Mitte
        if ($bA) { [void]$buchstabeVerwendet.Add($bA) }
        if ($bB) { [void]$buchstabeVerwendet.Add($bB) }
        $name = if ($bA -and $bB -and $bA.T -ceq $bB.T) { "Schnitt $($bA.T)" } elseif ($bA) { "Schnitt $($bA.T)" } elseif ($bB) { "Schnitt $($bB.T)" } else { "Schnittlinie bei $([math]::Round($p.A.Mitte.X)) / $([math]::Round($p.A.Mitte.Y))" }
        $px = $p.A.Mitte.X; $py = $p.A.Mitte.Y
        $problem = $false
        if ($p.A.Richtung -ne $p.B.Richtung) {
            $problem = $true
            $ergebnisse.Add((New-Result $name $false '' "Die beiden Dreiecke der Schnittlinie zeigen in unterschiedliche Richtungen ($($p.A.Richtung) und $($p.B.Richtung)). Beide Dreiecke müssen in dieselbe Blickrichtung zeigen." $px $py))
        }
        if (($bA -and $bB -and $bA.T -cne $bB.T)) {
            $problem = $true
            $ergebnisse.Add((New-Result $name $false '' "Die Schnittlinie ist an den Enden unterschiedlich beschriftet ($($bA.T) und $($bB.T)). Beide Enden brauchen dieselbe Bezeichnung." $px $py))
        } elseif ((($null -ne $bA) -xor ($null -ne $bB))) {
            $problem = $true
            $fehlt = if ($bA) { 'am zweiten Ende' } else { 'am ersten Ende' }
            $ergebnisse.Add((New-Result $name $false '' "Die Schnittlinie ist nur an einem Ende beschriftet ($fehlt fehlt die Bezeichnung). Beschriftet man die Schnittlinie, dann an beiden Enden." $px $py))
        }
        if (-not $problem) {
            $wert = if ($bA -and $bB) { "Dreiecke beide $($p.A.Richtung), an beiden Enden beschriftet" } else { "Dreiecke beide $($p.A.Richtung), ohne Buchstaben" }
            $ergebnisse.Add((New-Result $name $true $wert '' $px $py))
        }
    }

    # 2. Einzelnes Dreieck neben einem Buchstaben ohne Gegenstück: die Schnittlinie ist nur an einem Ende gezeichnet
    foreach ($d in @($gross | Where-Object { -not $benutzt.Contains($_) })) {
        $b = Get-NaechsterBuchstabe $d.Mitte
        if (-not $b) { continue }   # ein einzelnes Dreieck ohne Buchstaben kann ein anderes Symbol sein
        $ergebnisse.Add((New-Result "Schnitt $($b.T)" $false '' "Bei der Schnittlinie $($b.T) fehlt an einem Ende das Dreieck für die Blickrichtung (nur ein Dreieck gefunden)." $d.Mitte.X $d.Mitte.Y))
    }
    # 3. Gar keine Schnittlinie
    if ($ergebnisse.Count -eq 0) {
        $ergebnisse.Add((New-Result 'Schnittlinie' $false '' 'Es wurde keine Schnittlinie gefunden (gesucht: Strich-Punkt-Linie mit zwei ausgefüllten Dreiecken an den Enden).'))
    }
    $ergebnisse | Sort-Object { $_.Ok }, Angabe
}

function Get-A6Schnittlinien($items, $pdfPfad) {
    Get-A6Pruefung $items @(Get-PdfDreieckeCached $pdfPfad)
}

$script:Pruefungen += @{
    Id     = 'A6'
    Name   = 'Schnittlinien'
    Phasen = @('entwurf', 'werk')
    Ki     = $false
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A6Schnittlinien $items $pdfPfad }
}

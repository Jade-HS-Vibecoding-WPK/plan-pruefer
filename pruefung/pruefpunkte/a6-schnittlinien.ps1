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
    - Als Schnitt-Dreieck zählt eine Kantenlänge ab 8 Punkt. Kleinere Dreiecke (Maßketten, Achsen) werden ignoriert.
    - In Werkplänen tragen auch Achsen gleiche Buchstaben an beiden Enden. A6 sieht sie als Schnittbuchstaben,
      meldet aber nur, wenn ein einzelner Buchstabe ohne Gegenstück bleibt.
#>

$script:A6_DreieckMinKante = 8      # Mindestkantenlänge eines Schnitt-Dreiecks (Punkt im PDF)
$script:A6_MinAbstand = 100         # Mindestabstand der beiden Enden (Punkt)
$script:A6_Linientoleranz = 8       # so genau müssen die beiden Enden auf einer Linie liegen
$script:A6_BuchstabenNaehe = 45     # so nah muss ein Buchstabe an einem Dreieck stehen, um dazuzugehören

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
    $gross = @($dreiecke | Where-Object { $_.Kante -ge $script:A6_DreieckMinKante })
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
    $buchstaben = @($items | Where-Object { $_.T -cmatch '^[A-Z]$' })
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

    # 2. Buchstabenpaare ohne zwei Dreiecke: ein Ende ohne Dreieck
    $uebrig = @($buchstaben | Where-Object { -not $buchstabeVerwendet.Contains($_) })
    foreach ($gruppe in ($uebrig | Group-Object T | Sort-Object Name)) {
        $offen = New-Object System.Collections.Generic.List[object]
        foreach ($b in $gruppe.Group) { $offen.Add($b) }
        $i = 0
        while ($i -lt $offen.Count) {
            $partner = $null
            for ($j = $i + 1; $j -lt $offen.Count; $j++) { if (Test-A6AufLinie $offen[$i] $offen[$j]) { $partner = $j; break } }
            if ($null -ne $partner) {
                $a = $offen[$i]; $b = $offen[$partner]
                $dA = $gross | Where-Object { -not $benutzt.Contains($_) -and (Get-A6Abstand $_.Mitte $a) -le $script:A6_BuchstabenNaehe } | Select-Object -First 1
                $dB = $gross | Where-Object { -not $benutzt.Contains($_) -and (Get-A6Abstand $_.Mitte $b) -le $script:A6_BuchstabenNaehe } | Select-Object -First 1
                $anzahl = @($dA, $dB | Where-Object { $_ }).Count
                if ($anzahl -eq 2) {
                    # beide Enden haben ein Dreieck, aber sie bilden kein Paar (andere Größe)
                    $ergebnisse.Add((New-Result "Schnitt $($gruppe.Name)" $true "Buchstabe $($gruppe.Name) an beiden Enden" '' $a.X $a.Y))
                } else {
                    $ende = if ($anzahl -eq 1) { 'an einem Ende' } else { 'an beiden Enden' }
                    $ergebnisse.Add((New-Result "Schnitt $($gruppe.Name)" $false '' "Bei der Schnittlinie $($gruppe.Name) fehlt $ende das Dreieck für die Blickrichtung." $a.X $a.Y))
                }
                $offen.RemoveAt($partner); $offen.RemoveAt($i)
            } else { $i++ }
        }
        foreach ($rest in $offen) {
            $ergebnisse.Add((New-Result "Schnitt $($rest.T)" $false '' "Die Schnittbezeichnung '$($rest.T)' steht nur an einem Ende. Eine Schnittlinie braucht an beiden Enden dieselbe Bezeichnung." $rest.X $rest.Y))
        }
    }

    # 3. Gar keine Schnittlinie
    if ($ergebnisse.Count -eq 0) {
        $ergebnisse.Add((New-Result 'Schnittlinie' $false '' 'Es wurde keine Schnittlinie gefunden (gesucht: Strich-Punkt-Linie mit zwei ausgefüllten Dreiecken an den Enden).'))
    }
    $ergebnisse | Sort-Object { $_.Ok }, Angabe
}

function Get-A6Schnittlinien($items, $pdfPfad) {
    Get-A6Pruefung $items @(Get-PdfDreiecke $pdfPfad)
}

$script:Pruefungen += @{
    Id     = 'A6'
    Name   = 'Schnittlinien'
    Phasen = @('entwurf', 'werk')
    Ki     = $false
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A6Schnittlinien $items $pdfPfad }
}

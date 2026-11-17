<#
  A6 Schnittlinien: Ist mindestens ein Schnitt eingezeichnet, und ist er an beiden Enden beschriftet?

  Eine Schnittlinie hat an jedem Ende dieselbe Bezeichnung, zum Beispiel ein "A" oben und ein "A" unten
  (Schnitt A-A). Die Buchstaben stehen als Text im PDF. Erkannt wird ein Schnitt, wenn derselbe einzelne
  Großbuchstabe zweimal im Plan steht, weit voneinander entfernt und auf einer Linie (senkrecht oder waagerecht).

  Geprüft wird:
    1. Mindestens eine Schnittlinie ist vorhanden.
    2. Jede Schnittbezeichnung steht an beiden Enden. Ein einzelner Buchstabe ohne Gegenstück wird gemeldet.

  Nicht geprüft (braucht die KI, siehe A6K): die Blickrichtung (Dreiecke oder Pfeile am Ende der Linie).

  Grenze: In Werkplänen tragen auch Achsen gleiche Buchstaben an beiden Enden. Dann sieht A6 auch Achsen als
  Schnitte. Das Vorhandensein eines Schnitts kann dort also nur bedingt bestätigt werden.
#>

$script:A6_MinAbstand = 100   # Mindestabstand der beiden Enden (Punkt im PDF)
$script:A6_Linientoleranz = 8 # so genau müssen die beiden Buchstaben auf einer Linie stehen

function Get-A6Schnittlinien($items) {
    $buchstaben = @($items | Where-Object { $_.T -cmatch '^[A-Z]$' })
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $paarAnzahl = 0
    $einzeln = New-Object System.Collections.Generic.List[object]

    foreach ($gruppe in ($buchstaben | Group-Object T | Sort-Object Name)) {
        $offen = New-Object System.Collections.Generic.List[object]
        foreach ($b in $gruppe.Group) { $offen.Add($b) }
        # Paare bilden: zwei gleiche Buchstaben weit auseinander und auf einer Linie
        $i = 0
        while ($i -lt $offen.Count) {
            $a = $offen[$i]; $partner = $null
            for ($j = $i + 1; $j -lt $offen.Count; $j++) {
                $c = $offen[$j]
                $dx = [math]::Abs($a.X - $c.X); $dy = [math]::Abs($a.Y - $c.Y)
                $weit = [math]::Sqrt($dx * $dx + $dy * $dy) -ge $script:A6_MinAbstand
                $aufLinie = ($dx -le $script:A6_Linientoleranz) -or ($dy -le $script:A6_Linientoleranz)
                if ($weit -and $aufLinie) { $partner = $j; break }
            }
            if ($null -ne $partner) {
                $paarAnzahl++
                $ergebnisse.Add((New-Result "Schnitt $($gruppe.Name)" $true 'an beiden Enden beschriftet' '' $a.X $a.Y))
                $offen.RemoveAt($partner); $offen.RemoveAt($i)
            } else { $i++ }
        }
        foreach ($rest in $offen) { $einzeln.Add($rest) }
    }

    # Einzelne Buchstaben: ein einzelnes "N" ist der Nordpfeil und kein Schnitt
    $nCount = @($einzeln | Where-Object { $_.T -ceq 'N' }).Count
    foreach ($e in $einzeln) {
        if ($e.T -ceq 'N' -and $nCount -eq 1) { continue }
        $ergebnisse.Add((New-Result "Schnitt $($e.T)" $false '' "Die Schnittbezeichnung '$($e.T)' steht nur an einem Ende. Eine Schnittlinie braucht an beiden Enden dieselbe Bezeichnung." $e.X $e.Y))
    }

    if ($paarAnzahl -eq 0 -and @($ergebnisse | Where-Object { -not $_.Ok }).Count -eq 0) {
        $ergebnisse.Add((New-Result 'Schnittlinie' $false '' 'Es wurde keine Schnittlinie gefunden (gesucht: dieselbe Bezeichnung, zum Beispiel A, an beiden Enden einer Linie).'))
    }
    $ergebnisse | Sort-Object { $_.Ok }, Angabe
}

$script:Pruefungen += @{
    Id     = 'A6'
    Name   = 'Schnittlinien'
    Phasen = @('entwurf', 'werk')
    Ki     = $false
    Run    = { param($items, $pdfPfad) Get-A6Schnittlinien $items }
}

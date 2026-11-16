<#
  A4 Raumflächen: Hat jeder Raum eine Flächenangabe?

  Entscheidend ist die Zahl mit Quadratmeter-Einheit, ob "NGF:" davorsteht, ist egal
  (die Raumstempel liest raumstempel.ps1).

  Geprüft wird:
    1. Jede Flächenangabe hat einen Zahlenwert größer als 0.
    2. Jeder Raum, dessen Name in der Raumnamen-Liste steht, hat darunter eine Flächenangabe.
       (So wird auch ein Raum gefunden, bei dem die ganze Fläche im Stempel fehlt.)
#>

function Get-A4Raumflaechen($items) {
    $ergebnisse = New-Object System.Collections.Generic.List[object]
    $stempel = @(Get-Raumstempel $items)

    # 1. Jede Flächenangabe prüfen
    foreach ($s in $stempel) {
        $raum = if ($s.NameText) { $s.NameText } else { '(ohne Namen)' }
        if ($s.Zahl -le 0) {
            $ergebnisse.Add((New-Result "Raum $raum" $false "$($s.Wert) m²" "Die Fläche von '$raum' ist 0 oder keine gültige Zahl." $s.X $s.Y))
        } else {
            $ergebnisse.Add((New-Result "Raum $raum" $true "$($s.Wert) m²" '' $s.X $s.Y))
        }
    }

    # 2. Räume mit bekanntem Namen, unter denen keine Flächenangabe steht
    foreach ($k in @(Get-RaumnamenOhneFlaeche $items $stempel)) {
        $ergebnisse.Add((New-Result "Raum $($k.T)" $false '' "Im Raumstempel von '$($k.T)' fehlt die Flächenangabe (Zahl in m²)." $k.X $k.Y))
    }

    $ergebnisse | Sort-Object { $_.Ok }, Angabe
}

$script:Pruefungen += @{
    Id     = 'A4'
    Name   = 'Raumflächen'
    Phasen = @('entwurf', 'werk')
    Run    = { param($items) Get-A4Raumflaechen $items }
}

<#
  A3 Raumbezeichnungen: Hat jeder Raum einen Namen?

  Jede Flächenangabe im Plan gehört zu einem Raum. Steht über der Fläche kein Raumname, meldet A3
  einen Befund. Es werden nur Befunde zurückgegeben, in Ordnung gibt es keine eigene Meldung
  (die Räume mit Namen listet A4 Raumflächen).

  Grenze: Ein Raum, bei dem sowohl Name als auch Fläche fehlen, steht nicht im PDF-Text und kann mit
  dieser Prüfung nicht gefunden werden. Dafür bräuchte es die Wandgeometrie oder eine KI.
#>

function Get-A3Raumbezeichnungen($items) {
    foreach ($s in @(Get-Raumstempel $items | Where-Object { -not $_.Name } | Sort-Object Y, X)) {
        New-Result "Raum ohne Namen ($($s.Wert) m²)" $false "$($s.Wert) m²" "Zu der Fläche $($s.Wert) m² fehlt der Raumname. Jeder Raum braucht eine Bezeichnung (zum Beispiel Flur, Büro)." $s.X $s.Y
    }
}

$script:Pruefungen += @{
    Id     = 'A3'
    Name   = 'Raumbezeichnungen'
    Phasen = @('entwurf', 'werk')
    Run    = { param($items) Get-A3Raumbezeichnungen $items }
}

<#
  A7 Höhenangaben: Ist im Grundriss eine Höhenkote (Fußbodenhöhe) angegeben?

  Beide Hochschul-Checklisten fordern Höhenkoten im Grundriss (Entwurf: "wesentliche Höhenkoten",
  Werk: "Höhenkoten"). Erkannt werden Höhenkoten mit Vorzeichen und zwei Nachkommastellen, zum Beispiel:

      ±0,00     +0,00     -0,15     + 2,76     ±0.00     OKFF +2,76     0,00 (nur mit OKFF davor)

  Geprüft wird in dieser Version: Mindestens eine Höhenkote ist im Plan vorhanden.

  Noch nicht geprüft: "Höhen an Raumebenen" (Stufen, abgesenkte oder erhöhte Bereiche wie Bad oder Terrasse).
  Dafür muss erst festgelegt werden, welche Räume eine eigene Höhenangabe brauchen (siehe PRUEFKATALOG.md).
#>

$script:A7_Hoehenkote = '(?<h>[±+\-−–]\s?\d{1,3}[,.]\d{2})(?!\d)'
$script:A7_HoehenkoteMitOK = '(?i)\bOK\s?(FF|RF|FB|F|R)\b\.?\s*[:=]?\s*(?<h>[±+\-−–]?\s?\d{1,3}[,.]\d{2})(?!\d)'

function Get-A7Hoehenangaben($items) {
    $gefunden = New-Object System.Collections.Generic.List[object]
    foreach ($p in $items) {
        if ($p.T -match $script:A7_HoehenkoteMitOK -or $p.T -match $script:A7_Hoehenkote) {
            $gefunden.Add(@{ Wert = $Matches['h'].Trim(); X = $p.X; Y = $p.Y })
        }
    }
    if ($gefunden.Count -eq 0) {
        return New-Result 'Höhenangabe (Fußbodenhöhe)' $false '' 'Im Grundriss ist keine Höhenkote angegeben (zum Beispiel ±0,00 für die Fußbodenhöhe des Geschosses).'
    }
    $werte = ($gefunden | ForEach-Object { $_.Wert } | Select-Object -Unique) -join ', '
    New-Result 'Höhenangabe (Fußbodenhöhe)' $true $werte '' $gefunden[0].X $gefunden[0].Y
}

$script:Pruefungen += @{
    Id     = 'A7'
    Name   = 'Höhenangaben'
    Phasen = @('entwurf', 'werk')
    Ki     = $false
    Run    = { param($items, $pdfPfad) Get-A7Hoehenangaben $items }
}

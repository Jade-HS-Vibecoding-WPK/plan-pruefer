<#
  A1 Nordpfeil: Ist ein Nordpfeil im Grundriss vorhanden?

  Beide Hochschul-Checklisten fordern den Nordpfeil im Grundriss. Es reicht, dass er vorhanden ist,
  die Richtung wird nicht geprüft.

  Ein ArchiCAD-Nordpfeil besteht aus einem Kreis mit Kreuz und dem Buchstaben "N" darüber. Der Kreis ist Zeichnung,
  der Buchstabe steht als Text im PDF. Geprüft wird deshalb, ob ein einzelnes großes "N" als eigener Text im Plan
  steht (nicht "NGF:" oder andere Wörter).

  Grenze: Ein Nordpfeil OHNE Buchstaben (nur Kreis oder Pfeil) wird so nicht erkannt und führt zu einem Befund,
  obwohl er vorhanden ist. Ein "N" ohne Nordpfeil-Zeichnung würde als Nordpfeil durchgehen. Das Bild lässt sich
  nur mit der KI sicher beurteilen.
#>

function Get-A1Nordpfeil($items) {
    $n = @($items | Where-Object { $_.T -ceq 'N' })
    if ($n.Count -ge 1) {
        return New-Result 'Nordpfeil' $true "N bei $([math]::Round($n[0].X)), $([math]::Round($n[0].Y))" '' $n[0].X $n[0].Y
    }
    New-Result 'Nordpfeil' $false '' "Es wurde kein Nordpfeil gefunden (gesucht: der Buchstabe N neben dem Nordpfeil). Hat der Plan einen Nordpfeil ohne Buchstaben, ist dieser Befund unberechtigt."
}

$script:Pruefungen += @{
    Id     = 'A1'
    Name   = 'Nordpfeil'
    Phasen = @('entwurf', 'werk')
    Ki     = $false
    Run    = { param($items, $pdfPfad, $bildPfad) Get-A1Nordpfeil $items }
}

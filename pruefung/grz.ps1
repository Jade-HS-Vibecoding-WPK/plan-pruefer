<#
  Add-on GRZ-Prüfer (Experiment, 19.11.): Serverteil.

  Liest aus einem Grundriss (PDF) die Geschosse, die Raumflächen je Geschoss und, wenn der Plan
  Maßketten und ein Achsraster hat, das Gebäuderechteck (Breite mal Tiefe aus den Gesamtmaßen).
  Es gibt keine Online-Abfrage und keine Bindung an eine Stadt oder ein Bundesland: Grundstücksgröße, GRZ und
  Jahr des Bebauungsplans gibt das Team von Hand ein.

  Gerechnet wird im Browser (web/grz.js), Regeln nach der Arbeitshilfe GRZ/GFZ (Ordner grz-gfz/).
  Ohne diese Datei läuft der Planprüfer unverändert weiter (der Server lädt sie nur, wenn sie da ist).
#>


# Grundriss lesen: Geschosse mit Raumflächen (nur Zahlen mit Komma, wie beim Raumprogramm) und Gebäuderechteck
function Get-GrzGrundriss($items, [string]$pdfPfad) {
    $r = Get-RaumprogrammRaeume @($items)
    $geschosse = @($r.geschosse)
    $gruppen = @{}
    foreach ($rm in @($r.raeume)) {
        $g = if ($rm.geschoss) { [string]$rm.geschoss } else { '' }
        if (-not $gruppen.ContainsKey($g)) { $gruppen[$g] = New-Object System.Collections.Generic.List[object] }
        $gruppen[$g].Add(@{ name = [string]$rm.name; flaeche = [double]$rm.flaeche })
    }
    $liste = @(foreach ($k in $gruppen.Keys) { @{ name = $k; raeume = @($gruppen[$k].ToArray()) } })
    # Gebäuderechteck aus den Gesamtmaßen der Maßketten (braucht Achsraster, sonst nichts)
    $rechteck = $null
    try {
        if ($pdfPfad -and (Test-Path $pdfPfad) -and (Get-Command Get-A2Gesamtmasse -ErrorAction SilentlyContinue)) {
            $gm = Get-A2Gesamtmasse @($items) @(Get-PdfLinienCached $pdfPfad)
            if ($gm -and $gm.Breite -gt 0 -and $gm.Tiefe -gt 0) { $rechteck = @{ breite = [double]$gm.Breite; tiefe = [double]$gm.Tiefe } }
        }
    } catch { $rechteck = $null }
    @{ geschosse = $geschosse; gruppen = $liste; rechteck = $rechteck }
}

<#
  Raumstempel lesen (gemeinsam genutzt von A3 Raumbezeichnungen und A4 Raumflächen).

  Ein Raumstempel besteht aus dem Raumnamen und darunter der Fläche. Entscheidend ist die Zahl
  mit Quadratmeter-Einheit. Ob davor "NGF:" steht, ist egal. Diese Schreibweisen werden erkannt:

      Flur                Flur               Flur
      NGF: 22,50 m²       22,50 m²           NGF: 22,50

  (die Einheit darf als "m²", "m2" oder als "m" mit hochgestellter 2 im PDF stehen)

  Get-Raumstempel liefert pro Flächenangabe einen Stempel mit:
    Name      das Textstück mit dem Raumnamen (oder $null, wenn kein Name darüber steht)
    NameText  der Raumname als Text (oder $null)
    Wert      die Flächenzahl als Text, zum Beispiel "22,50"
    Zahl      die Flächenzahl als Zahl
    X, Y      Position für Markierungen (beim Namen, sonst bei der Zahl)
    AnkerX    Spalte des Stempels
    Mit       $true, wenn eine "NGF:"-Beschriftung vor der Zahl steht
  Die Raumnamen-Liste kann ergänzt werden: weitere Namen in $script:Raumnamen eintragen (durch | getrennt).
#>

# "Eingang" steht nicht in der Liste: In Plänen ist es oft nur eine Beschriftung am Eingang, kein Raum (Team 18.11.).
# Ein Eingangsraum mit Stempel (Name und Fläche) wird trotzdem erkannt, nur ein Name ohne Fläche wird nicht gemeldet.
$script:Raumnamen = '^(Flur|Diele|Windfang|Büro|Küche|Kochen|Wohnen|Essen|Wohnen/Essen|Wohnen/Kochen|Wohn(?!ung)\w*|Ess\w*|Schlafen|Schlaf\w*|Kind\w*|Eltern\w*|Gäste\w*|Arbeits\w*|Zimmer\w*|Bad|Bad\w*|WC|Gäste-?WC|Dusche|HWR|Hauswirtschaft\w*|Technik\w*|Abstell\w*|Speisekammer|Vorrat\w*|Ankleide|Keller|Lager\w*|Werkstatt|Heizung\w*|Garage|Carport|Gartenhaus|Terrasse|Balkon|Loggia|Treppenhaus)$'
$script:FlaechenLabel = '^(NGF|NF|BGF|Fläche)\s*:?$'
$script:FlaechenKomma = '^\d{1,4}[.,]\d{1,2}$'
$script:FlaechenInline = '^(?:(?:NGF|NF|BGF|Fläche)\s*:?\s*)?(?<w>\d{1,4}(?:[.,]\d{1,2})?)\s*m\s*[²2]$'
$script:FlaechenInlineOhneEinheit = '^(?:NGF|NF|BGF|Fläche)\s*:?\s*(?<w>\d{1,4}(?:[.,]\d{1,2})?)$'

# Findet alle Flächenangaben im Plan. Jede hat: Wert, X, Y (Lage der Zahl), AnkerX (Spalte des Stempels), Mit
function Get-RaumFlaechen($items) {
    $flaechen = New-Object System.Collections.Generic.List[object]
    $benutzt = New-Object System.Collections.Generic.HashSet[object]
    $labels = @($items | Where-Object { $_.T -match $script:FlaechenLabel })

    # a) alles in einem Stück: "22,50 m²" oder "NGF: 22,50 m²" oder "NGF: 22,50"
    foreach ($p in $items) {
        if ($p.T -match $script:FlaechenInline -or $p.T -match $script:FlaechenInlineOhneEinheit) {
            [void]$benutzt.Add($p)
            $flaechen.Add(@{ Wert = $Matches['w']; X = $p.X; Y = $p.Y; AnkerX = $p.X; Mit = $false })
        }
    }

    # b) Zahl mit Komma, rechts daneben die Einheit "m" mit hochgestellter 2 (oder "m²" als eigenes Stück)
    foreach ($n in @($items | Where-Object { $_.T -match $script:FlaechenKomma -and -not $benutzt.Contains($_) })) {
        $einheit = $items | Where-Object {
            [math]::Abs($_.Y - $n.Y) -le 2.5 -and $_.X -gt $n.X -and ($_.X - $n.X) -le 40 -and $_.T -match '^m(\s*[²2])?$'
        } | Sort-Object X | Select-Object -First 1
        if (-not $einheit) { continue }
        if ($einheit.T -eq 'm') {
            $hoch = $items | Where-Object {
                $_.T -match '^[²2]$' -and $_.X -gt $einheit.X -and ($_.X - $einheit.X) -le 15 -and [math]::Abs($_.Y - $einheit.Y) -le 6
            } | Select-Object -First 1
            if (-not $hoch) { continue }
        }
        [void]$benutzt.Add($n)
        # "NGF:" links in derselben Zeile (bis 80 Punkt, wie bei c; in manchen Stempeln steht die Zahl rechtsbündig weiter weg)
        $label = $labels | Where-Object { [math]::Abs($_.Y - $n.Y) -le 2.5 -and $_.X -lt $n.X -and ($n.X - $_.X) -le 80 } | Sort-Object { $n.X - $_.X } | Select-Object -First 1
        $flaechen.Add(@{ Wert = $n.T; X = $n.X; Y = $n.Y; AnkerX = $(if ($label) { $label.X } else { $n.X }); Mit = [bool]$label })
    }

    # c) "NGF:" mit Zahl daneben, aber ohne Einheit
    foreach ($l in $labels) {
        $n = $items | Where-Object {
            [math]::Abs($_.Y - $l.Y) -le 2.5 -and $_.X -gt $l.X -and ($_.X - $l.X) -le 80 -and $_.T -match '^\d{1,4}([.,]\d{1,2})?$' -and -not $benutzt.Contains($_)
        } | Sort-Object X | Select-Object -First 1
        if ($n) {
            [void]$benutzt.Add($n)
            $flaechen.Add(@{ Wert = $n.T; X = $n.X; Y = $n.Y; AnkerX = $l.X; Mit = $true })
        }
    }
    $flaechen
}

# Ordnet jeder Flächenangabe den Raumnamen darüber zu.
function Get-Raumstempel($items) {
    foreach ($f in @(Get-RaumFlaechen $items)) {
        $toleranz = if ($f.Mit) { 20 } else { 45 }
        $name = $items | Where-Object {
            $_.T -match '[A-Za-zÄÖÜäöüß]{2,}' -and $_.T -notmatch $script:FlaechenLabel -and $_.T -notmatch $script:FlaechenInline -and $_.T -notmatch $script:FlaechenInlineOhneEinheit -and
            [math]::Abs($_.X - $f.AnkerX) -le $toleranz -and ($f.Y - $_.Y) -ge 5 -and ($f.Y - $_.Y) -le 30
        } | Sort-Object { ($f.Y - $_.Y) + [math]::Abs($_.X - $f.AnkerX) * 0.2 } | Select-Object -First 1

        $zahl = 0.0
        [void][double]::TryParse(($f.Wert -replace ',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$zahl)
        [pscustomobject]@{
            Name     = $name
            NameText = $(if ($name) { $name.T } else { $null })
            Wert     = $f.Wert
            Zahl     = $zahl
            X        = $(if ($name) { $name.X } else { $f.X })
            Y        = $(if ($name) { $name.Y } else { $f.Y })
            AnkerX   = $f.AnkerX
            ZahlY    = $f.Y
            Mit      = $f.Mit
        }
    }
}

# Räume mit bekanntem Namen, unter denen keine Flächenangabe steht (wird von A4 genutzt).
# Ein Raumname steht allein in seiner Zeile. Steht links davon ein weiteres Wort, ist es Teil eines Satzes
# (zum Beispiel "Neubau eines Einfamilienhauses mit Carport" im Plankopf) und kein Raumstempel.
function Get-RaumnamenOhneFlaeche($items, $stempel) {
    $genutzt = New-Object System.Collections.Generic.HashSet[object]
    foreach ($s in $stempel) { if ($s.Name) { [void]$genutzt.Add($s.Name) } }
    foreach ($k in @($items | Where-Object {
                $k = $_
                $_.T -match $script:Raumnamen -and -not $genutzt.Contains($_) -and
                -not ($items | Where-Object { $_ -ne $k -and [math]::Abs($_.Y - $k.Y) -le 1.5 -and $_.X -lt $k.X -and ($k.X - $_.X) -lt 60 })
            })) {
        $darunter = $stempel | Where-Object { [math]::Abs($_.AnkerX - $k.X) -le 45 -and ($_.ZahlY - $k.Y) -ge 5 -and ($_.ZahlY - $k.Y) -le 30 } | Select-Object -First 1
        if (-not $darunter) { $k }
    }
}

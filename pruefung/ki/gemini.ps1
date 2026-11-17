<#
  KI-Baustein: spricht mit Google Gemini. Das ist der EINZIGE Ort, an dem die App einen KI-Dienst anruft.
  Soll später ein anderer Dienst genutzt werden (zum Beispiel Claude), wird nur diese Datei ausgetauscht:
  Invoke-KiPdfFrage muss danach weiter "PDF + Frage + Schema hinein, ausgewertetes Ergebnis heraus" liefern.

  Einrichtung (siehe README, Abschnitt "KI-Prüfung einrichten"):
    - Schlüssel von Google AI Studio holen und als erste Zeile in die Datei schluessel.txt im Projektordner schreiben
      (oder die Umgebungsvariable GEMINI_API_KEY setzen). schluessel.txt steht in der .gitignore und wird nie hochgeladen.
    - Optional zweite Zeile "modell=gemini-3.5-flash-lite" oder Umgebungsvariable PLANPRUEFER_KI_MODELL.

  Wichtig: Der Schlüssel wird nie angezeigt, nie in Meldungen oder Protokolle geschrieben.
#>

$script:KiStandardModell = 'gemini-3.5-flash-lite'
$script:KiApiRevision = '2026-05-20'
$script:KiBasis = 'https://generativelanguage.googleapis.com/v1beta'

# Platzhalter aus der Vorlage zählt nicht als Schlüssel.
$script:KiPlatzhalter = 'HIER-DEN-SCHLUESSEL-EINFUEGEN'

# Liest schluessel.txt (oder schluessel.env, .env). Erlaubt sind zwei Schreibweisen:
#   AIza...                    (nur der Schlüssel in einer Zeile)
#   GEMINI_API_KEY=AIza...     (".env"-Schreibweise, auch GOOGLE_API_KEY, API_KEY, KEY)
function Get-KiSchluesselAusZeilen($zeilen) {
    foreach ($z in @($zeilen | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })) {
        $wert = $null
        if ($z -match '^(?i:GEMINI_API_KEY|GOOGLE_API_KEY|API_KEY|KEY|SCHLUESSEL)\s*=\s*(.+)$') { $wert = $Matches[1] }
        elseif ($z -notmatch '^\w+\s*=') { $wert = $z }
        if ($wert) {
            $wert = $wert.Trim().Trim('"').Trim("'").Trim()
            if ($wert -and $wert -ne $script:KiPlatzhalter) { return $wert }
        }
    }
    return $null
}

function Get-KiEinstellung([string]$Name) {
    foreach ($dateiName in 'schluessel.txt', 'schluessel.env', '.env') {
        $datei = Join-Path $PSScriptRoot "..\..\$dateiName"
        if (-not (Test-Path $datei)) { continue }
        $zeilen = @(Get-Content $datei -Encoding UTF8)
        if ($Name -eq 'schluessel') {
            $k = Get-KiSchluesselAusZeilen $zeilen
            if ($k) { return $k }
        } else {
            $z = @($zeilen | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^$Name\s*=" }) | Select-Object -First 1
            if ($z) { return ($z.Substring($z.IndexOf('=') + 1)).Trim().Trim('"').Trim("'") }
        }
    }
    return $null
}

function Get-KiSchluessel {
    if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY.Trim() }
    return (Get-KiEinstellung 'schluessel')
}

function Get-KiModell {
    if ($env:PLANPRUEFER_KI_MODELL) { return $env:PLANPRUEFER_KI_MODELL.Trim() }
    $m = Get-KiEinstellung 'modell'
    if ($m) { return $m }
    return $script:KiStandardModell
}

function Test-KiVerfuegbar { return [bool](Get-KiSchluessel) }

# Liest die Fehlermeldung aus einer Antwort des Dienstes, ohne den Schlüssel preiszugeben.
function Get-KiFehlerText($ex) {
    $code = $null; $text = ''
    if ($ex.Exception.Response) {
        $code = [int]$ex.Exception.Response.StatusCode
        try {
            $sr = New-Object System.IO.StreamReader($ex.Exception.Response.GetResponseStream())
            $roh = $sr.ReadToEnd()
            $j = $roh | ConvertFrom-Json -ErrorAction Stop
            $e = if ($j -is [array]) { $j[0].error } else { $j.error }
            if ($e.message) { $text = [string]$e.message }
        } catch { }
    } else { $text = $ex.Exception.Message }
    $key = Get-KiSchluessel
    if ($key) { $text = $text.Replace($key, '***') }
    return @{ Code = $code; Text = $text }
}

function Get-KiAntwortText($r) {
    if ($r.output_text) { return [string]$r.output_text }
    # Interactions-API: Schritte (steps), der Schritt "model_output" enthält den Antworttext
    if ($r.steps) {
        $teile = @($r.steps | Where-Object { $_.type -eq 'model_output' } | ForEach-Object { @($_.content) | ForEach-Object { if ($_.text) { [string]$_.text } } })
        if ($teile.Count -gt 0) { return ($teile -join '') }
    }
    foreach ($feld in 'outputs', 'output') {
        if ($r.$feld) {
            $teile = @($r.$feld | ForEach-Object {
                    if ($_.text) { [string]$_.text }
                    elseif ($_.content) { @($_.content) | ForEach-Object { if ($_.text) { [string]$_.text } } }
                })
            if ($teile.Count -gt 0) { return ($teile -join '') }
        }
    }
    if ($r.candidates) {
        $teile = @($r.candidates[0].content.parts | ForEach-Object { if ($_.text) { [string]$_.text } })
        if ($teile.Count -gt 0) { return ($teile -join '') }
    }
    throw "Die Antwort der KI hatte ein unbekanntes Format (Felder: $(($r.PSObject.Properties.Name) -join ', '))."
}

function ConvertFrom-KiJson([string]$text) {
    $t = $text.Trim()
    $t = $t -replace '^```(json)?\s*', '' -replace '\s*```$', ''
    return ($t | ConvertFrom-Json)
}

# PDF + Frage an Gemini schicken und eine Antwort im vorgegebenen JSON-Schema zurückbekommen.
# Wirft einen Fehler mit deutscher Meldung, wenn etwas schiefgeht.
function Invoke-KiPdfFrage([string]$PdfPfad, [string]$Frage, $Schema) {
    $key = Get-KiSchluessel
    if (-not $key) { throw 'Kein KI-Schlüssel hinterlegt (siehe README, Abschnitt "KI-Prüfung einrichten").' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($PdfPfad))
    $modell = Get-KiModell

    $versuche = @(
        @{
            Url     = "$script:KiBasis/interactions"
            Headers = @{ 'x-goog-api-key' = $key; 'Api-Revision' = $script:KiApiRevision }
            Body    = @{
                model           = $modell
                input           = @(
                    @{ type = 'document'; data = $b64; mime_type = 'application/pdf' },
                    @{ type = 'text'; text = $Frage }
                )
                response_format = @{ type = 'text'; mime_type = 'application/json'; schema = $Schema }
            }
        },
        @{
            Url     = "$script:KiBasis/models/${modell}:generateContent"
            Headers = @{ 'x-goog-api-key' = $key }
            Body    = @{
                contents         = @(@{ parts = @(@{ inline_data = @{ mime_type = 'application/pdf'; data = $b64 } }, @{ text = $Frage }) })
                generationConfig = @{ responseMimeType = 'application/json'; responseJsonSchema = $Schema }
            }
        }
    )

    $letzterFehler = $null
    foreach ($v in $versuche) {
        try {
            $json = $v.Body | ConvertTo-Json -Depth 20 -Compress
            $h = $v.Headers.Clone(); $h['Content-Type'] = 'application/json; charset=utf-8'
            $antwort = Invoke-RestMethod -Uri $v.Url -Method Post -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 180
            return (ConvertFrom-KiJson (Get-KiAntwortText $antwort))
        } catch {
            $f = Get-KiFehlerText $_
            $letzterFehler = $f
            # Schlüssel, Limit oder Netz: der zweite Weg würde dasselbe Ergebnis liefern, also sofort abbrechen
            if ($f.Code -in 401, 403, 429 -or $f.Text -match 'API key') { break }
            if ($null -eq $f.Code -and $f.Text -notmatch 'Antwort|JSON|Format') { break }
        }
    }
    if ($letzterFehler.Text -match 'API key') { throw 'Die KI hat den Schlüssel abgelehnt (ungültig). Bitte schluessel.txt prüfen und einen gültigen Schlüssel aus Google AI Studio eintragen.' }
    switch ($letzterFehler.Code) {
        { $_ -in 401, 403 } { throw "Die KI hat den Schlüssel abgelehnt. Bitte schluessel.txt prüfen. ($($letzterFehler.Text))" }
        429 { throw 'Das kostenlose KI-Limit ist erreicht. Bitte in ein paar Minuten noch einmal versuchen.' }
        default { throw "Die KI-Anfrage ist fehlgeschlagen. $($letzterFehler.Text)" }
    }
}

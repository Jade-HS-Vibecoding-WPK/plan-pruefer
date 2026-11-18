<#
  Planprüfer: kleiner Webserver für die Plankopf-Prüfung (läuft nur auf diesem Rechner).

  Start:  Doppelklick auf "Planpruefer-starten.cmd" im Projektordner
          oder: powershell -File pruefung\server.ps1
  Dann im Browser öffnen: http://localhost:8080
  Beenden: Strg+C im Fenster oder das Fenster schließen.
#>
param([int]$Port = 8080)

. "$PSScriptRoot\pruefungen.ps1"

$webOrdner = Join-Path $PSScriptRoot 'web'
$tempOrdner = Join-Path ([System.IO.Path]::GetTempPath()) 'planpruefer'
New-Item -ItemType Directory -Force $tempOrdner | Out-Null

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try { $listener.Start() } catch {
    Write-Host "Der Server konnte nicht gestartet werden. Läuft er schon, oder ist Port $Port belegt?" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}
Write-Host "Planprüfer läuft: http://localhost:$Port   (beenden mit Strg+C)" -ForegroundColor Green

function Send-Bytes($ctx, [byte[]]$bytes, [string]$type, [int]$status = 200) {
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $type
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

function Send-Json($ctx, $obj, [int]$status = 200) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($json)) 'application/json; charset=utf-8' $status
}

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        try {
            $path = $req.Url.AbsolutePath
            if ($req.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
                $html = [System.IO.File]::ReadAllBytes((Join-Path $webOrdner 'index.html'))
                # Seite nicht zwischenspeichern: sonst zeigt der Browser nach Änderungen noch die alte Fassung
                $ctx.Response.AddHeader('Cache-Control', 'no-store')
                Send-Bytes $ctx $html 'text/html; charset=utf-8'
            }
            elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/status') {
                # Sagt der Seite, ob die KI-Prüfung eingerichtet ist (der Schlüssel selbst wird nie gesendet)
                Send-Json $ctx @{ ki = (Test-KiVerfuegbar); modell = (Get-KiModell) }
            }
            elseif ($req.HttpMethod -eq 'POST' -and $path -eq '/bild') {
                # Bild der Planseite (PNG) für die KI-Prüfungen zwischenspeichern. Die Seite schickt es vor der Prüfung
                # und nennt danach die Nummer im Kopf X-Bild.
                if ($req.ContentLength64 -gt 30MB) { Send-Json $ctx @{ fehler = 'Das Bild ist zu groß.' } 413; continue }
                $bildId = [guid]::NewGuid().ToString('N')
                $bildDatei = Join-Path $tempOrdner "$bildId.png"
                try {
                    $fs = [System.IO.File]::Create($bildDatei)
                    $req.InputStream.CopyTo($fs)
                    $fs.Close()
                    $kopf = [System.IO.File]::ReadAllBytes($bildDatei) | Select-Object -First 4
                    if (($kopf -join ',') -ne '137,80,78,71') {
                        Remove-Item $bildDatei -Force -ErrorAction SilentlyContinue
                        Send-Json $ctx @{ fehler = 'Das ist kein PNG-Bild.' } 400
                        continue
                    }
                    Send-Json $ctx @{ id = $bildId }
                } catch {
                    Remove-Item $bildDatei -Force -ErrorAction SilentlyContinue
                    throw
                }
            }
            elseif ($req.HttpMethod -eq 'POST' -and $path -eq '/pruefen') {
                $name = [System.Uri]::UnescapeDataString([string]$req.Headers['X-Dateiname'])
                if (-not $name) { $name = 'plan.pdf' }
                $phase = ([string]$req.Headers['X-Phase']).ToLowerInvariant()
                if ($phase -ne 'entwurf' -and $phase -ne 'werk') {
                    Send-Json $ctx @{ fehler = 'Bitte zuerst die Planungsphase wählen (Entwurf oder Werkplanung).' } 400
                    continue
                }
                if ($req.ContentLength64 -gt 100MB) {
                    Send-Json $ctx @{ fehler = 'Die Datei ist zu groß (maximal 100 MB).' } 413
                    continue
                }
                $tmp = Join-Path $tempOrdner ([guid]::NewGuid().ToString() + '.pdf')
                try {
                    $fs = [System.IO.File]::Create($tmp)
                    $req.InputStream.CopyTo($fs)
                    $fs.Close()
                    $kopf = [System.IO.File]::ReadAllBytes($tmp) | Select-Object -First 5
                    if (([System.Text.Encoding]::ASCII.GetString($kopf)) -ne '%PDF-') {
                        Send-Json $ctx @{ fehler = 'Das ist keine PDF-Datei.' } 400
                        continue
                    }
                    $mitKi = ([string]$req.Headers['X-Ki']).ToLowerInvariant() -eq 'ja'
                    $bildPfad = ''
                    $bildNr = [string]$req.Headers['X-Bild']
                    if ($bildNr -match '^[0-9a-f]{32}$' -and (Test-Path (Join-Path $tempOrdner "$bildNr.png"))) { $bildPfad = Join-Path $tempOrdner "$bildNr.png" }
                    $res = @(Invoke-Pruefungen $tmp $phase $mitKi $bildPfad)
                    $meldungen = @(Get-Meldungen)
                    $befunde = @($res | ForEach-Object {
                            @{ angabe = $_.Angabe; ok = [bool]$_.Ok; wert = [string]$_.Wert; hinweis = [string]$_.Detail; punkt = [string]$_.Punkt; quelle = [string]$_.Quelle; x = $_.X; y = $_.Y }
                        })
                    Write-Host ("{0}  {1} ({2}{3})  ->  {4} Befund(e)" -f (Get-Date -Format 'HH:mm:ss'), $name, $phase, $(if ($mitKi) { ', mit KI' } else { '' }), @($res | Where-Object { -not $_.Ok }).Count)
                    Send-Json $ctx @{ datei = $name; phase = $phase; mitKi = $mitKi; befunde = $befunde; aktiv = @(Get-AktivePruefungen $phase $mitKi); meldungen = $meldungen }
                } finally {
                    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
                    if ($bildPfad -and (Test-Path $bildPfad)) { Remove-Item $bildPfad -Force -ErrorAction SilentlyContinue }
                }
            }
            else {
                Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes('Nicht gefunden')) 'text/plain; charset=utf-8' 404
            }
        } catch {
            Write-Host ("Fehler: " + $_.Exception.Message) -ForegroundColor Red
            try { Send-Json $ctx @{ fehler = 'Beim Prüfen ist ein Fehler aufgetreten.' } 500 } catch { }
        }
    }
} finally {
    $listener.Stop()
}

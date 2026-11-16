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
                Send-Bytes $ctx $html 'text/html; charset=utf-8'
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
                    $res = @(Invoke-Pruefungen $tmp $phase)
                    $befunde = @($res | ForEach-Object {
                            @{ angabe = $_.Angabe; ok = [bool]$_.Ok; wert = [string]$_.Wert; hinweis = [string]$_.Detail }
                        })
                    Write-Host ("{0}  {1} ({2})  ->  {3} Befund(e)" -f (Get-Date -Format 'HH:mm:ss'), $name, $phase, @($res | Where-Object { -not $_.Ok }).Count)
                    Send-Json $ctx @{ datei = $name; phase = $phase; befunde = $befunde; aktiv = @(Get-AktivePruefungen $phase) }
                } finally {
                    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
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

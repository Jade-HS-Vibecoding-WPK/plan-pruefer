@echo off
rem Startet den Planpruefer und oeffnet ihn im Browser.
cd /d "%~dp0"
start "" "http://localhost:8080"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruefung\server.ps1"
pause

# End-to-end terminal test: demo server + OS, driven via API, screenshot.
# Hardened: unique HTTP port, every step time-boxed, processes ALWAYS killed by PID.
$ErrorActionPreference = 'Continue'
Get-Process mslrt -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 1

$port = 8900 + (Get-Random -Minimum 0 -Maximum 99)
$demoLog = "$PWD\tools\testrun2\demo.log"
$osLog = "$PWD\tools\testrun\run.log"
New-Item -ItemType Directory -Force tools\testrun, tools\testrun2 | Out-Null
Remove-Item "$PWD\tools\testrun\term.png" -ErrorAction SilentlyContinue

$p1 = Start-Process -FilePath "$PWD\mslrt.exe" -ArgumentList @('-headless', '-data', "$PWD\tools\testrun2", "$PWD\terminal-demo.mrc") -RedirectStandardOutput $demoLog -RedirectStandardError "$PWD\tools\testrun2\demo.err" -PassThru -WindowStyle Hidden
$p2 = Start-Process -FilePath "$PWD\mslrt.exe" -ArgumentList @('-headless', '-http', "127.0.0.1:$port", '-data', "$PWD\tools\testrun", "$PWD\msl-os.mrc") -RedirectStandardOutput $osLog -RedirectStandardError "$PWD\tools\testrun\run.err" -PassThru -WindowStyle Hidden
"demo pid: $($p1.Id)  os pid: $($p2.Id)  api port: $port"

try {
  # wait for the API to answer, max 8s
  $api = "http://127.0.0.1:$port"
  $up = $false
  foreach ($i in 1..16) {
    Start-Sleep -Milliseconds 500
    if ($p2.HasExited) { "os process exited early"; break }
    try { Invoke-RestMethod -Method Post -Uri "$api/exec" -ContentType 'application/json' -Body (@{line = 'echo -s ping'} | ConvertTo-Json) -TimeoutSec 2 | Out-Null; $up = $true; break } catch {}
  }
  if (-not $up) { "API never came up"; throw "no api" }

  $exec = {
    param($line)
    try { return Invoke-RestMethod -Method Post -Uri "$api/exec" -ContentType 'application/json' -Body (@{line = $line} | ConvertTo-Json) -TimeoutSec 5 } catch { return "ERR: $_" }
  }
  & $exec 'mo.term.open' | Out-Null
  Start-Sleep 1
  & $exec 'mo.term.line telnet 127.0.0.1 2323' | Out-Null
  Start-Sleep 4
  & $exec 'mo.term.line colours' | Out-Null
  Start-Sleep 1
  & $exec 'mo.term.line joke' | Out-Null
  Start-Sleep 2
  & $exec 'drawsave @MSLTERM term.png' | Out-Null
  & $exec 'echo -s TERM lines= $hget(mt,n) echo= $hget(mt,echo) rcvd= $sock(mosterm).rcvd rq= $sock(mosterm).rq' | Out-Null
  Start-Sleep 1
  "--- os log tail ---"
  Get-Content $osLog -ErrorAction SilentlyContinue | Select-Object -Last 6
  Get-Content "$PWD\tools\testrun\run.err" -ErrorAction SilentlyContinue | Select-Object -Last 4
  "--- demo log tail ---"
  Get-Content $demoLog -ErrorAction SilentlyContinue | Select-Object -Last 4
}
finally {
  foreach ($p in @($p1, $p2)) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  }
  "processes cleaned up"
}

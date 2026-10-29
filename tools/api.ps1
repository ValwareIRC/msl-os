# Drive a running mslrt control API (default http://127.0.0.1:8871)
param(
  [string]$Port = "8871",
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Lines
)
$uri = "http://127.0.0.1:$Port/exec"
foreach ($l in $Lines) {
  $r = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body (@{line = $l} | ConvertTo-Json)
  if ($r.error) { "ERR: $($r.error)" }
}

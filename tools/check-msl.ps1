# Dev-time sanity checker for msl-os.mrc
# - brace/paren balance (comment lines ignored)
# - alias definitions vs references
param([string]$File = "msl-os.mrc")

$lines = Get-Content $File
$code = foreach ($l in $lines) { if ($l -notmatch '^\s*;') { $l } }
$text = $code -join "`n"

function Count-Char([string]$s, [char]$c) { ($s.ToCharArray() | Where-Object { $_ -eq $c }).Count }

$open = Count-Char $text '{'
$close = Count-Char $text '}'
"braces: { $open  } $close  $(if ($open -eq $close) {'OK'} else {'*** MISMATCH ***'})"

$po = Count-Char $text '('
$pc = Count-Char $text ')'
"parens: ( $po  ) $pc  $(if ($po -eq $pc) {'OK'} else {'*** MISMATCH ***'})"

# alias definitions (single-line and braced)
$defs = @()
for ($i = 0; $i -lt $code.Count; $i++) {
  if ($code[$i] -match '^\s*alias\s+(-l\s+)?([a-zA-Z0-9_.]+)') { $defs += $Matches[2] }
}
$dups = $defs | Group-Object | Where-Object Count -gt 1
"aliases defined: $($defs.Count)"
if ($dups) { foreach ($d in $dups) { "  *** DUPLICATE alias: $($d.Name) x$($d.Count)" } }

# references: mo.* and mt.* tokens used anywhere
$refs = @{}
foreach ($m in [regex]::Matches($text, '(?<![a-zA-Z0-9_.])((?:mo|mt)\.[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*)')) {
  $refs[$m.Groups[1].Value] = $true
}

# aliases invoked via %cmd execution are plain strings in hit entries - covered above.

$missing = @()
foreach ($r in $refs.Keys) {
  if ($defs -contains $r) { continue }
  # dynamic dispatch prefixes built with $+ at runtime
  $dynamicPrefixes = @('mo.app.explorer.', 'mo.app.browser.', 'mo.app.paint.', 'mo.app.viewer.', 'mo.app.welcome.')
  $ok = $false
  foreach ($p in $dynamicPrefixes) { if ($r.StartsWith($p)) { $ok = $true } }
  if (-not $ok) { $missing += $r }
}
if ($missing) {
  "referenced but not defined (check each):"
  $missing | Sort-Object | ForEach-Object { "  $_" }
} else {
  "references: all resolve (or are dynamic dispatch)"
}

# Shared helpers: config + rotating log (no notifications)
$ErrorActionPreference = 'Continue'
$Cfg = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force $Cfg.log_dir | Out-Null
function Write-Log([string]$Name, [string]$Msg) {
  $p = Join-Path $Cfg.log_dir "$Name.log"
  if ((Test-Path $p) -and ((Get-Item $p).Length -gt $Cfg.log_max_mb * 1MB)) {
    for ($i = $Cfg.log_keep - 1; $i -ge 1; $i--) { if (Test-Path "$p.$i") { Move-Item -Force "$p.$i" "$p.$($i+1)" } }
    Move-Item -Force $p "$p.1"
  }
  Add-Content -Path $p -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Msg) -Encoding utf8
}
function Unload-Ollama {
  try {
    foreach ($m in (Invoke-RestMethod "$($Cfg.ollama_url)/api/ps" -TimeoutSec 5).models) {
      $b = @{ model = $m.name; keep_alive = 0 } | ConvertTo-Json
      Invoke-RestMethod "$($Cfg.ollama_url)/api/generate" -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 30 | Out-Null
      Write-Log 'llm_stage' "unloaded $($m.name) to free VRAM"
    }
  } catch { Write-Log 'llm_stage' "unload failed: $_" }
}

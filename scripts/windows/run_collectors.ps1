# Light collectors (CPU/network). Task Scheduler runs this hidden, Below Normal priority.
. (Join-Path $PSScriptRoot 'common.ps1')
if (Test-Path $Cfg.pause_flag) { Write-Log 'collectors' 'PAUSE flag present; skipping'; exit 0 }
[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'
Set-Location $Cfg.repo
$env:PYTHONIOENCODING = 'utf-8'
foreach ($a in $Cfg.collectors) {
  $t = Get-Date
  $o = & $Cfg.python @a 2>&1 | Out-String
  Write-Log 'collectors' ("{0} exit={1} {2:N0}s :: {3}" -f ($a -join ' '), $LASTEXITCODE, ((Get-Date) - $t).TotalSeconds, ($o.Trim() -replace '\s+', ' '))
}

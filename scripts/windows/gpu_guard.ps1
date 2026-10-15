<# Is the GPU free of other users? Exit 0 = OK to run LLM work, 1 = busy/cooling down.
   Uses Windows per-process GPU counters (GPU Engine utilization, GPU Process Memory dedicated VRAM),
   excluding Ollama/system processes. After any other GPU user is seen, stays "busy" until the GPU
   has been free for resume_after_free_seconds. Prints one JSON line unless -Quiet. #>
param([switch]$Quiet)
. (Join-Path $PSScriptRoot 'common.ps1')
$reasons = @(); $users = @{}
$ignore = @($Cfg.ignore_processes)
function PidOf($inst) { if ($inst -match 'pid_(\d+)') { [int]$Matches[1] } }
try {
  $eng = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -EA Stop).CounterSamples
  $eng | Group-Object { PidOf $_.InstanceName } | ForEach-Object {
    $u = ($_.Group | Measure-Object CookedValue -Sum).Sum
    if ($_.Name -and $u -ge $Cfg.other_gpu_util_percent) { $users[[int]$_.Name] = @{ util = [math]::Round($u, 1) } } }
  $mem = (Get-Counter '\GPU Process Memory(*)\Dedicated Usage' -EA Stop).CounterSamples
  $mem | Group-Object { PidOf $_.InstanceName } | ForEach-Object {
    $mb = ($_.Group | Measure-Object CookedValue -Sum).Sum / 1MB
    if ($_.Name -and $mb -ge $Cfg.other_gpu_vram_mb) { $k = [int]$_.Name; if (-not $users[$k]) { $users[$k] = @{} }; $users[$k].vram_mb = [int]$mb } }
} catch { $reasons += "counter_error:$($_.Exception.Message)" }
foreach ($procId in @($users.Keys)) {
  $n = (Get-Process -Id $procId -EA SilentlyContinue).ProcessName
  if (-not $n -or $ignore -contains $n) { continue }
  $d = $users[$procId]; $reasons += ("gpu_user:{0}(pid {1}{2}{3})" -f $n, $procId, $(if ($d.util) { ", $($d.util)%" }), $(if ($d.vram_mb) { ", $($d.vram_mb)MB" }))
}
$listed = Get-Process -EA SilentlyContinue | Where-Object { $Cfg.always_busy_processes -contains $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique
foreach ($n in $listed) { $reasons += "listed_app:$n" }
$otherUser = $reasons.Count -gt 0
# Cool-down: require the GPU to be free of others for N seconds before resuming
$now = Get-Date; $state = @{ last_busy = $null }
if (Test-Path $Cfg.state_file) { try { $state = Get-Content $Cfg.state_file -Raw | ConvertFrom-Json } catch {} }
if ($otherUser) { $state = @{ last_busy = $now.ToString('o') }; $state | ConvertTo-Json | Set-Content $Cfg.state_file }
elseif ($state.last_busy) {
  $free = ($now - [datetime]$state.last_busy).TotalSeconds
  if ($free -lt $Cfg.resume_after_free_seconds) { $reasons += "cooldown:{0:N0}s/{1}s" -f $free, $Cfg.resume_after_free_seconds }
}
if (Test-Path $Cfg.pause_flag) { $reasons += 'pause_flag' }
if (Test-Path $Cfg.llm_pause_flag) { $reasons += 'llm_pause_flag' }
$ok = $reasons.Count -eq 0
$out = [ordered]@{ ok = $ok; other_gpu_user = $otherUser; reasons = $reasons } | ConvertTo-Json -Compress
Write-Log 'gpu_guard' $out
if (-not $Quiet) { $out }
exit ([int](-not $ok))

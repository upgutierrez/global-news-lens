<# Continuous LLM worker. Loops: guard -> run one batch (pipeline.llm_stage) -> sleep.
   When another GPU user appears: unload Ollama models (keep_alive 0) and wait; resumes automatically
   after the GPU has been free for resume_after_free_seconds. Task Scheduler restarts it if it exits.
   pipeline.llm_stage re-checks the guard between items via GNL_GUARD_CMD and exits early if busy. #>
param([int]$MaxLoops = 0)
. (Join-Path $PSScriptRoot 'common.ps1')
[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'
Set-Location $Cfg.repo
$env:PYTHONIOENCODING = 'utf-8'
$guard = Join-Path $PSScriptRoot 'gpu_guard.ps1'
$env:GNL_GUARD_CMD = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guard`" -Quiet"
$loops = 0; $wasBusy = $false
while ($true) {
  if (Test-Path $Cfg.pause_flag) { Write-Log 'llm_stage' 'PAUSE flag; exiting'; Unload-Ollama; break }
  & $guard -Quiet
  if ($LASTEXITCODE -ne 0) {
    if (-not $wasBusy) { Write-Log 'llm_stage' 'GPU busy (see gpu_guard.log); pausing and freeing VRAM'; Unload-Ollama; $wasBusy = $true }
    Start-Sleep -Seconds $Cfg.busy_poll_seconds
  } else {
    if ($wasBusy) { Write-Log 'llm_stage' 'GPU free; resuming'; $wasBusy = $false }
    $o = & $Cfg.python -m pipeline.llm_stage 2>&1 | Out-String
    $rc = $LASTEXITCODE
    Write-Log 'llm_stage' ("batch exit={0} :: {1}" -f $rc, ($o.Trim() -replace '\s+', ' '))
    if ($rc -eq 3) { Unload-Ollama; $wasBusy = $true }   # stage aborted because GPU got busy
    Start-Sleep -Seconds $Cfg.loop_sleep_seconds
  }
  $loops++; if ($MaxLoops -gt 0 -and $loops -ge $MaxLoops) { break }
}

# Registers user-level scheduled tasks (no admin). Safe to re-run; replaces the GNL tasks.
$dir = $PSScriptRoot
$user = "$env:USERDOMAIN\$env:USERNAME"
$prin = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
function Act($ps1) { New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dir\hidden.vbs`" `"$ps1`"" -WorkingDirectory $dir }
function Rep($min) { New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes $min) }
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -Priority 7
Register-ScheduledTask -TaskName 'GNL-Collectors' -TaskPath '\GlobalNewsLens\' -Action (Act "$dir\run_collectors.ps1") -Trigger (Rep 20) -Settings $set -Principal $prin -Description 'Global News Lens: collectors every 20 min (hidden, below normal)' -Force | Out-Null
$llmset = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -Priority 7
Register-ScheduledTask -TaskName 'GNL-LLMWorker' -TaskPath '\GlobalNewsLens\' -Action (Act "$dir\run_llm_stage.ps1") -Trigger @((New-ScheduledTaskTrigger -AtLogOn -User $user), (Rep 10)) -Settings $llmset -Principal $prin -Description 'Global News Lens: continuous LLM worker; pauses when another app uses the GPU' -Force | Out-Null
$olset = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'GNL-Ollama-Start' -TaskPath '\GlobalNewsLens\' -Action (Act "$dir\start_ollama.ps1") -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $user) -Settings $olset -Principal $prin -Description 'Start Ollama hidden + tailscale serve at logon' -Force | Out-Null
Get-ScheduledTask -TaskPath '\GlobalNewsLens\' | Select-Object TaskName, State

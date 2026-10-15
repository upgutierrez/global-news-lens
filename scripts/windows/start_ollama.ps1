# Sets Ollama background env for this process tree, then runs Derek's existing start script hidden.
# (Task Scheduler does not always see freshly-set user env vars, so set them explicitly here.)
$env:OLLAMA_KEEP_ALIVE = '5m'
$env:OLLAMA_MAX_LOADED_MODELS = '1'
$env:OLLAMA_NUM_PARALLEL = '1'
$env:OLLAMA_MODELS = 'D:\ollama\models'
& 'D:\Ollama\Start-Ollama-Tailscale.ps1'

"""LLM stage, one batch (stub). Called in a loop by scripts/windows/run_llm_stage.ps1.

Contract for the real implementation:
- Process pending items one at a time; call guard_ok() before each item.
- If guard_ok() is False: stop, and exit with code 3 so the runner unloads models (keep_alive 0).
- Exit 0 when the batch is finished (or there is nothing to do), 2 if Ollama is unreachable.
"""
import json, os, subprocess, sys, urllib.request

OLLAMA = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
BUSY = 3

def guard_ok() -> bool:
    cmd = os.environ.get("GNL_GUARD_CMD")
    return True if not cmd else subprocess.run(cmd, shell=True, capture_output=True).returncode == 0

def ollama_models():
    with urllib.request.urlopen(f"{OLLAMA}/api/tags", timeout=10) as r:
        return [m["name"] for m in json.load(r)["models"]]

def pending_items():
    return []  # TODO: read unanalyzed clusters/items from the DB

def main():
    try:
        models = ollama_models()
    except Exception as e:
        print(f"ollama unreachable: {e}"); return 2
    items = pending_items()
    for it in items:
        if not guard_ok():
            print("GPU busy; aborting batch"); return BUSY
        # TODO: analyst + cross-origin judge per docs/architecture.md
    print(f"stub ok: {len(models)} models, {len(items)} pending items")
    return 0

if __name__ == "__main__":
    sys.exit(main())

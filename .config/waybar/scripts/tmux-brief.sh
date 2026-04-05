#!/usr/bin/env bash
set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

if ! tmux ls >/dev/null 2>&1; then
  exit 0
fi

python3 - <<'PY'
import json, subprocess

try:
    out = subprocess.check_output(
        ["tmux", "list-sessions", "-F", "#{session_name}\t#{?session_attached,attached,detached}"],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip()
except Exception:
    raise SystemExit(0)

if not out:
    raise SystemExit(0)

rows = [line.split("\t", 1) for line in out.splitlines() if line.strip()]
count = len(rows)
attached = sum(1 for _, state in rows if state == "attached")
text = f" {count}"
cls = "attached" if attached else "ok"
items = [f"{name} ({state})" for name, state in rows]
tooltip = "tmux sessions\n" + "\n".join(items)
print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}, ensure_ascii=False))
PY

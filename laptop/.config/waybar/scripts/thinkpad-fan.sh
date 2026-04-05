#!/usr/bin/env bash
set -euo pipefail

fan_file="/proc/acpi/ibm/fan"

if [[ ! -r "$fan_file" ]]; then
  printf '{"text":"󰈐 ?","tooltip":"ThinkPad fan info unavailable","class":"missing"}\n'
  exit 0
fi

get_field() {
  local key="$1"
  awk -F: -v k="$key" '
    $1 == k {
      sub(/^[[:space:]]+/, "", $2)
      print $2
      exit
    }
  ' "$fan_file"
}

status="$(get_field status)"
speed="$(get_field speed)"
level="$(get_field level)"

status="${status:-unknown}"
speed="${speed:-unknown}"
level="${level:-unknown}"

python3 - <<'PY' "$status" "$level" "$speed"
import json, sys
status, level, speed = sys.argv[1:4]
icon = "󰈐"
cls = "normal"

def rpm_text(raw: str) -> str:
    if not raw.isdigit():
        return "auto"
    n = int(raw)
    if n >= 1000:
        return f"{n/1000:.1f}k"
    return str(n)

if status == "disabled" and level == "0":
    text = f"{icon} off"
    cls = "muted"
elif level == "auto":
    text = f"{icon} {rpm_text(speed)}"
elif level in {"disengaged", "full-speed"}:
    text = f"{icon} !!"
    cls = "critical"
elif level.isdigit():
    text = f"{icon} {level}"
    if int(level) >= 6:
        cls = "warning"
else:
    text = f"{icon} ?"
    cls = "warning"

tooltip = f"Fan status: {status}\nLevel: {level}\nSpeed: {speed} RPM"
print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}, ensure_ascii=False))
PY

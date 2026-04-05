#!/usr/bin/env bash
set -euo pipefail

location="${WAYBAR_WEATHER_LOCATION:-Willemsoord,Steenwijkerland}"
# Set WAYBAR_WEATHER_LOCATION=auto to let wttr.in use automatic IP-based location.
if [[ "$location" == "auto" ]]; then
  query=""
else
  query="$(python3 - <<'PY' "$location"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
)"
  query="/${query}"
fi

brief="$(curl -sf --max-time 4 "https://wttr.in${query}?format=%c+%t" || true)"
detail="$(curl -sf --max-time 4 "https://wttr.in${query}?format=j1" || true)"

if [[ -z "$brief" ]]; then
  printf '{"text":"󰖐 --","tooltip":"Weather unavailable","class":"offline"}\n'
  exit 0
fi

python3 - <<'PY' "$brief" "$detail" "$location"
import json, sys
from datetime import datetime

brief = sys.argv[1].strip()
detail_raw = sys.argv[2].strip()
requested_location = sys.argv[3].strip()


def to_float(value):
    try:
        return float(str(value).replace(',', '.'))
    except Exception:
        return None


def kmh_to_knots(value):
    num = to_float(value)
    if num is None:
        return "?"
    return str(round(num / 1.852))


def hpa_to_inhg(value):
    num = to_float(value)
    if num is None:
        return "?"
    return f"{num * 0.0295299831:.2f}"


def km_to_nm(value):
    num = to_float(value)
    if num is None:
        return "?"
    return f"{num / 1.852:.1f}"


def to_24h(value):
    value = (value or "").strip()
    if not value:
        return "?"
    for fmt in ("%I:%M %p", "%I:%M%p"):
        try:
            return datetime.strptime(value, fmt).strftime("%H:%M")
        except ValueError:
            pass
    return value

parts = brief.split()
if len(parts) >= 2:
    text = f"{parts[0]} {parts[1]}"
else:
    text = brief or "󰖐 --"

tooltip = "Weather unavailable"
cls = "ok"

if detail_raw:
    try:
        data = json.loads(detail_raw)
        area = data.get("nearest_area", [{}])[0].get("areaName", [{}])[0].get("value", "")
        region = data.get("nearest_area", [{}])[0].get("region", [{}])[0].get("value", "")
        country = data.get("nearest_area", [{}])[0].get("country", [{}])[0].get("value", "")
        cc = data.get("current_condition", [{}])[0]
        today = data.get("weather", [{}])[0]
        tomorrow = data.get("weather", [{}, {}])[1] if len(data.get("weather", [])) > 1 else {}

        desc = cc.get("weatherDesc", [{}])[0].get("value", "Unknown")
        temp_c = cc.get("temp_C", "?")
        feels = cc.get("FeelsLikeC", "?")
        humidity = cc.get("humidity", "?")
        wind_kmh = cc.get("windspeedKmph", "?")
        wind_kt = kmh_to_knots(wind_kmh)
        wind_dir = cc.get("winddir16Point", "?")
        precip = cc.get("precipMM", "0")
        uv = cc.get("uvIndex", "?")
        pressure_hpa = cc.get("pressure", "?")
        pressure_inhg = hpa_to_inhg(pressure_hpa)
        visibility_km = cc.get("visibility", "?")
        visibility_nm = km_to_nm(visibility_km)

        today_max = today.get("maxtempC", "?")
        today_min = today.get("mintempC", "?")
        sunrise = to_24h(today.get("astronomy", [{}])[0].get("sunrise", "?"))
        sunset = to_24h(today.get("astronomy", [{}])[0].get("sunset", "?"))

        lines = []
        display_place = area or requested_location
        if display_place:
            place_line = display_place
            extras = ", ".join(x for x in [region, country] if x and x != display_place)
            if extras:
                place_line = f"{place_line} — {extras}"
            lines.append(place_line)
            lines.append("")
        lines.append(f"Now: {desc}, {temp_c}°C")
        lines.append(f"Feels like: {feels}°C")
        lines.append(f"Wind: {wind_dir} {wind_kt} kt ({wind_kmh} km/h)")
        lines.append(f"Humidity: {humidity}%")
        lines.append(f"Precipitation: {precip} mm")
        lines.append(f"Pressure: {pressure_inhg} inHg ({pressure_hpa} hPa)")
        lines.append(f"Visibility: {visibility_nm} nm ({visibility_km} km)")
        lines.append(f"UV index: {uv}")
        lines.append("")
        lines.append(f"Today: {today_min}°C → {today_max}°C")
        lines.append(f"Sun: {sunrise} / {sunset}")

        if tomorrow:
            tmax = tomorrow.get("maxtempC", "?")
            tmin = tomorrow.get("mintempC", "?")
            hourly = tomorrow.get("hourly", [{}])
            probe = hourly[4] if len(hourly) > 4 else hourly[0]
            tdesc = probe.get("weatherDesc", [{}])[0].get("value", "")
            if tdesc:
                lines.append("")
                lines.append(f"Tomorrow: {tdesc}, {tmin}°C → {tmax}°C")

        tooltip = "\n".join(lines)
    except Exception:
        tooltip = brief

print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}, ensure_ascii=False))
PY

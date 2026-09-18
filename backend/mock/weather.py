"""data.gov.sg real-time weather (no key): 2-hour nowcast per area and
rainfall per station. Cached briefly so the demo never hammers the API."""
from __future__ import annotations

import math
import time
from datetime import datetime
from typing import Any

import httpx

BASE = "https://api-open.data.gov.sg/v2/real-time/api"
RAIN_WORDS = ("rain", "showers", "thundery", "thunderstorm", "drizzle")


class WeatherClient:
    def __init__(self) -> None:
        self._http = httpx.AsyncClient(timeout=20, headers={"User-Agent": "NAVI-hackathon-demo/0.2"})
        self._cache: dict[str, tuple[float, Any]] = {}

    async def _cached(self, path: str, ttl: float = 300) -> Any:
        now = time.time()
        hit = self._cache.get(path)
        if hit and now - hit[0] < ttl:
            return hit[1]
        r = await self._http.get(f"{BASE}/{path}")
        r.raise_for_status()
        body = r.json()
        if body.get("code") != 0:
            raise RuntimeError(f"data.gov.sg {path}: {body.get('errorMsg')}")
        self._cache[path] = (now, body["data"])
        return body["data"]

    async def now(self, lat: float, lon: float) -> dict[str, Any]:
        nowcast = await self._cached("two-hr-forecast")
        rainfall = await self._cached("rainfall", ttl=300)

        area = _nearest(nowcast.get("area_metadata", []), lat, lon, lambda a: a["label_location"])
        item = (nowcast.get("items") or [{}])[0]
        forecast = next((f["forecast"] for f in item.get("forecasts", []) if f["area"] == area["name"]), "Unknown") if area else "Unknown"

        station = _nearest(rainfall.get("stations", []), lat, lon, lambda s: s["location"])
        reading = (rainfall.get("readings") or [{}])[0]
        mm = 0.0
        if station:
            mm = float(next((d["value"] for d in reading.get("data", []) if d["stationId"] == station["id"]), 0) or 0)

        raining = any(w in forecast.lower() for w in RAIN_WORDS) or mm >= 0.2
        heavy = "heavy" in forecast.lower() or "thundery" in forecast.lower() or mm >= 5
        return {
            "source": "data.gov.sg",
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "area": area["name"] if area else None,
            "forecast": forecast,
            "validPeriod": (item.get("valid_period") or {}).get("text"),
            "rainfallMm": mm,
            "rainStation": station["name"] if station else None,
            "raining": raining,
            "heavy": heavy,
            "advice": (
                "Heavy rain: shorter walks and sheltered routes preferred; bring an umbrella."
                if heavy
                else "Rain: bring an umbrella; NAVI prefers routes with less walking."
                if raining
                else "Dry: walking legs are fine."
            ),
            "simulated": False,
        }


def _nearest(items: list[dict[str, Any]], lat: float, lon: float, loc) -> dict[str, Any] | None:
    best, best_d = None, math.inf
    for it in items:
        p = loc(it)
        d = (float(p["latitude"]) - lat) ** 2 + (float(p["longitude"]) - lon) ** 2
        if d < best_d:
            best, best_d = it, d
    return best

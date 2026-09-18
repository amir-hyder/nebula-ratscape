"""OpenStreetMap data via the public Overpass API, with a disk cache so the
demo queries each area once. Data © OpenStreetMap contributors (ODbL)."""
from __future__ import annotations

import hashlib
import json
import math
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import httpx

OVERPASS = "https://overpass-api.de/api/interpreter"
ATTRIBUTION = "© OpenStreetMap contributors"
CACHE_DIR = Path(__file__).resolve().parent / ".cache" / "osm"
CACHE_TTL = 24 * 3600

SAFE_TAGS = {
    "police": "Police post",
    "community_centre": "Community centre",
    "library": "Library",
    "clinic": "Clinic",
    "hospital": "Hospital",
    "place_of_worship": "Place of worship",
    "school": "School",
    "fire_station": "Fire station",
}


class OsmClient:
    def __init__(self) -> None:
        self._http = httpx.AsyncClient(
            timeout=45,
            headers={"User-Agent": "NAVI-hackathon-demo/0.2 (child commuter companion; contact via repo)"},
        )
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    async def _query(self, ql: str) -> list[dict[str, Any]]:
        key = hashlib.sha1(ql.encode()).hexdigest()
        path = CACHE_DIR / f"{key}.json"
        if path.exists() and time.time() - path.stat().st_mtime < CACHE_TTL:
            return json.loads(path.read_text())["elements"]
        r = await self._http.post(OVERPASS, data={"data": ql})
        r.raise_for_status()
        body = r.json()
        path.write_text(json.dumps(body))
        return body.get("elements", [])

    async def walk_features(self, points: list[list[float]]) -> dict[str, Any]:
        """Crossings, steps and covered footways within 25 m of a walking polyline."""
        pts = _thin(points, 40)
        if len(pts) < 2:
            return {"features": [], "attribution": ATTRIBUTION}
        line = ",".join(f"{p[0]:.5f},{p[1]:.5f}" for p in pts)
        ql = f"""[out:json][timeout:25];
(
  node["highway"="crossing"](around:25,{line});
  node["highway"="steps"](around:25,{line});
  way["highway"="steps"](around:25,{line});
  way["highway"~"footway|path"]["covered"="yes"](around:30,{line});
  node["amenity"="shelter"](around:40,{line});
);
out center 60;"""
        feats = []
        for e in await self._query(ql):
            tags = e.get("tags", {})
            lat, lon = _latlon(e)
            if lat is None or lon is None:
                continue
            if tags.get("highway") == "crossing":
                kind, label = "crossing", {"traffic_signals": "Crossing with lights", "zebra": "Zebra crossing", "marked": "Marked crossing", "unmarked": "Unmarked crossing"}.get(tags.get("crossing", ""), "Crossing")
            elif tags.get("highway") == "steps":
                kind, label = "steps", "Steps"
            elif tags.get("covered") == "yes":
                kind, label = "covered", "Sheltered walkway"
            else:
                kind, label = "shelter", "Shelter"
            feats.append({"kind": kind, "label": label, "lat": lat, "lon": lon, "osmId": f"{e['type']}/{e['id']}"})
        return {
            "source": "openstreetmap",
            "attribution": ATTRIBUTION,
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "features": feats,
        }

    async def safe_places(self, lat: float, lon: float, radius: int = 600) -> dict[str, Any]:
        """Staffed public places a child can go to when something feels wrong."""
        tags = "|".join(SAFE_TAGS)
        ql = f"""[out:json][timeout:25];
(
  nwr["amenity"~"^({tags})$"](around:{radius},{lat:.5f},{lon:.5f});
  node["shop"="convenience"](around:{min(radius, 400)},{lat:.5f},{lon:.5f});
);
out center 40;"""
        feats = []
        for e in await self._query(ql):
            tg = e.get("tags", {})
            plat, plon = _latlon(e)
            if plat is None or plon is None:
                continue
            kind = tg.get("amenity") or tg.get("shop") or "place"
            name = tg.get("name") or SAFE_TAGS.get(kind, kind.replace("_", " ").title())
            d = _haversine(lat, lon, plat, plon)
            feats.append({"kind": kind, "label": SAFE_TAGS.get(kind, "Convenience store"), "name": name, "lat": plat, "lon": plon, "distanceM": round(d)})
        feats.sort(key=lambda f: f["distanceM"])
        return {
            "source": "openstreetmap",
            "attribution": ATTRIBUTION,
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "features": feats[:12],
        }


def _latlon(e: dict[str, Any]) -> tuple[float | None, float | None]:
    if "lat" in e:
        return e["lat"], e["lon"]
    c = e.get("center")
    if c:
        return c["lat"], c["lon"]
    return None, None


def _thin(points: list[list[float]], max_n: int) -> list[list[float]]:
    if len(points) <= max_n:
        return points
    step = len(points) / max_n
    out = [points[int(i * step)] for i in range(max_n)]
    if out[-1] != points[-1]:
        out.append(points[-1])
    return out


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))

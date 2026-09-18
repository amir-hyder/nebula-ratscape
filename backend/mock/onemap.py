"""OneMap adapter: authentication, public-transport routing, walking routes,
geocoding, and normalisation into the NAVI RouteCandidate shape.

Credentials come from backend/.env and never leave this process.
"""
from __future__ import annotations

import hashlib
import os
import re
import time
from datetime import datetime
from typing import Any

import httpx

BASE = "https://www.onemap.gov.sg"

# OneMap/OTP route codes → NAVI line ids used by the disruption parser.
LINE_IDS = {
    "EW": "EWL", "CG": "EWL",
    "NS": "NSL",
    "CC": "CCL", "CE": "CCL",
    "DT": "DTL",
    "NE": "NEL",
    "TE": "TEL",
    "BP": "BPL",
    "SE": "SKL", "SW": "SKL", "STC": "SKL",
    "PE": "PGL", "PW": "PGL", "PTC": "PGL",
}


class OneMapError(RuntimeError):
    pass


class OneMapClient:
    def __init__(self, email: str | None, password: str | None) -> None:
        self.email = email
        self.password = password
        self._token: str | None = None
        self._expiry = 0.0
        self._http = httpx.AsyncClient(timeout=30)

    @property
    def configured(self) -> bool:
        return bool(self.email and self.password)

    async def token(self) -> str:
        if not self.configured:
            raise OneMapError("ONEMAP_EMAIL / ONEMAP_PASSWORD not set in backend/.env")
        if self._token and time.time() < self._expiry - 600:
            return self._token
        r = await self._http.post(
            f"{BASE}/api/auth/post/getToken",
            json={"email": self.email, "password": self.password},
        )
        if r.status_code != 200:
            raise OneMapError(f"OneMap auth failed: {r.status_code} {r.text[:200]}")
        body = r.json()
        token = str(body["access_token"])
        self._token = token
        self._expiry = float(body.get("expiry_timestamp", time.time() + 3600))
        return token

    async def _get(self, path: str, params: dict[str, Any]) -> Any:
        tok = await self.token()
        r = await self._http.get(f"{BASE}{path}", params=params, headers={"Authorization": tok})
        if r.status_code == 401:
            self._token = None
            tok = await self.token()
            r = await self._http.get(f"{BASE}{path}", params=params, headers={"Authorization": tok})
        if r.status_code != 200:
            raise OneMapError(f"OneMap {path} failed: {r.status_code} {r.text[:200]}")
        return r.json()

    async def geocode(self, query: str) -> list[dict[str, Any]]:
        body = await self._get(
            "/api/common/elastic/search",
            {"searchVal": query, "returnGeom": "Y", "getAddrDetails": "Y", "pageNum": 1},
        )
        out = []
        for res in body.get("results", [])[:5]:
            out.append({
                "name": res.get("SEARCHVAL"),
                "address": res.get("ADDRESS"),
                "lat": float(res["LATITUDE"]),
                "lon": float(res["LONGITUDE"]),
            })
        return out

    async def transit_routes(
        self,
        origin: tuple[float, float],
        destination: tuple[float, float],
        when: datetime,
        mode: str = "TRANSIT",
        num: int = 3,
        max_walk_m: int = 800,
    ) -> dict[str, Any]:
        body = await self._get(
            "/api/public/routingsvc/route",
            {
                "start": f"{origin[0]},{origin[1]}",
                "end": f"{destination[0]},{destination[1]}",
                "routeType": "pt",
                "date": when.strftime("%m-%d-%Y"),
                "time": when.strftime("%H:%M:%S"),
                "mode": mode,
                "maxWalkDistance": max_walk_m,
                "numItineraries": num,
            },
        )
        plan = body.get("plan") or {}
        itineraries = plan.get("itineraries") or []
        return {
            "source": "onemap",
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "mode": mode,
            "candidates": [normalise_itinerary(it, i, mode) for i, it in enumerate(itineraries)],
        }

    async def walk_route(self, origin: tuple[float, float], destination: tuple[float, float]) -> dict[str, Any]:
        body = await self._get(
            "/api/public/routingsvc/route",
            {"start": f"{origin[0]},{origin[1]}", "end": f"{destination[0]},{destination[1]}", "routeType": "walk"},
        )
        summary = body.get("route_summary") or {}
        return {
            "source": "onemap",
            "points": decode_polyline(body.get("route_geometry", "")),
            "distanceM": summary.get("total_distance"),
            "seconds": summary.get("total_time"),
            "instructions": [
                {"direction": ins[0], "street": ins[1], "distanceM": ins[2], "text": ins[9]}
                for ins in body.get("route_instructions", [])
                if len(ins) >= 10
            ],
        }


# ── Normalisation ─────────────────────────────────────────────────────

def pretty_name(name: str | None) -> str:
    if not name:
        return ""
    n = re.sub(r"\s+MRT STATION$", "", name.strip(), flags=re.I)
    n = re.sub(r"\s+(STN|STATION)$", "", n, flags=re.I)
    keep = {"MRT", "LRT", "BLK", "OPP", "BEF", "AFT", "STN", "CTR", "SQ", "RD", "AVE", "ST", "CC", "JC", "PR", "SEC", "SCH", "INT", "LOR"}
    words = []
    for w in n.split():
        words.append(w if w.upper() in keep or any(c.isdigit() for c in w) else w.capitalize())
    return " ".join(words)


def normalise_itinerary(it: dict[str, Any], index: int, mode: str) -> dict[str, Any]:
    legs_out = []
    prev_end = it.get("startTime")
    for leg in it.get("legs", []):
        m = leg.get("mode", "WALK").upper()
        is_walk = m == "WALK"
        route = (leg.get("route") or "").strip()
        line_id = None
        service_no = None
        if m in ("SUBWAY", "RAIL", "TRAM"):
            line_id = LINE_IDS.get(route.upper(), route.upper() or None)
            nmode = "rail"
        elif m == "BUS":
            service_no = route or None
            nmode = "bus"
        else:
            nmode = "walk"
        start = leg.get("startTime") or prev_end or 0
        end = leg.get("endTime") or start
        ride_min = max(1, round((end - start) / 60000)) if not is_walk else max(1, round(leg.get("duration", 60) / 60))
        wait_min = 0
        if not is_walk and prev_end:
            wait_min = max(0, round((start - prev_end) / 60000))
        stops = [pretty_name(leg["from"].get("name"))]
        stop_codes = [leg["from"].get("stopCode")]
        for s in leg.get("intermediateStops") or []:
            stops.append(pretty_name(s.get("name")))
            stop_codes.append(s.get("stopCode"))
        stops.append(pretty_name(leg["to"].get("name")))
        stop_codes.append(leg["to"].get("stopCode"))
        steps = [
            {
                "direction": st.get("relativeDirection"),
                "street": "" if st.get("bogusName") else st.get("streetName", ""),
                "distanceM": round(st.get("distance", 0)),
                "lat": st.get("lat"),
                "lon": st.get("lon"),
            }
            for st in (leg.get("steps") or [])
        ]
        legs_out.append({
            "mode": nmode,
            "from": pretty_name(leg["from"].get("name")) or "Start",
            "to": pretty_name(leg["to"].get("name")) or "Destination",
            "fromLatLon": [leg["from"].get("lat"), leg["from"].get("lon")],
            "toLatLon": [leg["to"].get("lat"), leg["to"].get("lon")],
            "minutes": ride_min,
            "waitMinutes": wait_min,
            "lineId": line_id,
            "serviceNo": service_no,
            "stops": stops if not is_walk else [],
            "stopCodes": [c for c in stop_codes] if not is_walk else [],
            "distanceM": round(leg.get("distance", 0)),
            "points": decode_polyline((leg.get("legGeometry") or {}).get("points", "")),
            "steps": steps,
            "realTime": bool(leg.get("realTime")),
        })
        prev_end = end
    fingerprint = "|".join(f"{l['mode']}:{l.get('lineId') or l.get('serviceNo') or ''}:{l['to']}" for l in legs_out)
    digest = hashlib.sha1(fingerprint.encode()).hexdigest()[:8]
    return {
        "id": f"onemap-{mode.lower()}-{index}-{digest}",
        "source": "onemap",
        "legs": legs_out,
        "totalMinutes": max(1, round(it.get("duration", 0) / 60)),
        "transfers": it.get("transfers", 0),
        "walkMinutes": round(it.get("walkTime", 0) / 60),
        "startTime": it.get("startTime"),
        "endTime": it.get("endTime"),
        "estimated": True,
    }


def decode_polyline(encoded: str, precision: int = 5) -> list[list[float]]:
    """Google encoded polyline → [[lat, lon], ...]."""
    if not encoded:
        return []
    factor = 10 ** precision
    coords: list[list[float]] = []
    index = lat = lon = 0
    while index < len(encoded):
        for is_lat in (True, False):
            result = shift = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            delta = ~(result >> 1) if result & 1 else result >> 1
            if is_lat:
                lat += delta
            else:
                lon += delta
        coords.append([round(lat / factor, 6), round(lon / factor, 6)])
    return coords

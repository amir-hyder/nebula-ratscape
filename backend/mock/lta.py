"""LTA DataMall adapter: train service alerts and bus arrivals.
The AccountKey stays in backend/.env."""
from __future__ import annotations

import re
import time
from datetime import datetime, timezone
from typing import Any

import httpx

BASE = "https://datamall2.mytransport.sg/ltaodataservice"

# Line codes differ between endpoints (see PS2 brief): NAVI id → crowding API codes.
CROWD_LINE = {"NSL": ["NSL"], "EWL": ["EWL", "CGL"], "CCL": ["CCL", "CEL"], "DTL": ["DTL"], "NEL": ["NEL"], "TEL": ["TEL"], "BPL": ["BPL"], "SKL": ["SLRT"], "PGL": ["PLRT"]}
CROWD_WORD = {"l": "low", "m": "moderate", "h": "high"}


class LtaError(RuntimeError):
    pass


class LtaClient:
    def __init__(self, account_key: str | None) -> None:
        self.key = account_key
        self._http = httpx.AsyncClient(timeout=20)
        self._crowd_cache: dict[str, tuple[float, dict[str, Any]]] = {}

    @property
    def configured(self) -> bool:
        return bool(self.key)

    async def _get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        if not self.key:
            raise LtaError("LTA_ACCOUNT_KEY not set in backend/.env")
        headers: dict[str, str] = {"AccountKey": self.key, "accept": "application/json"}
        r = await self._http.get(f"{BASE}/{path}", params=params, headers=headers)
        if r.status_code != 200:
            raise LtaError(f"LTA {path} failed: {r.status_code} {r.text[:200]}")
        return r.json()

    async def train_alerts(self) -> dict[str, Any]:
        body = await self._get("TrainServiceAlerts")
        value = body.get("value") or {}
        segments = []
        for seg in value.get("AffectedSegments") or []:
            stations = [s.strip() for s in (seg.get("Stations") or "").split(",") if s.strip()]
            segments.append({
                "lineId": seg.get("Line"),
                "direction": seg.get("Direction"),
                "stationCodes": stations,
                "freePublicBus": seg.get("FreePublicBus"),
                "freeMrtShuttle": seg.get("FreeMRTShuttle"),
            })
        messages = [
            {"content": m.get("Content"), "createdAt": m.get("CreatedDate")}
            for m in value.get("Message") or []
        ]
        return {
            "source": "lta-train",
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "status": "normal" if value.get("Status") == 1 else "disrupted",
            "affectedSegments": segments,
            "messages": messages,
            "simulated": False,
        }

    async def crowding(self, line_id: str) -> dict[str, Any]:
        """Station Crowd Density (real-time) for one NAVI line id, 10-minute cache.
        Line codes differ between LTA endpoints (see the PS2 brief), hence CROWD_LINE."""
        now = time.time()
        hit = self._crowd_cache.get(line_id)
        if hit and now - hit[0] < 600:
            return hit[1]
        levels: dict[str, str] = {}
        window = None
        for code in CROWD_LINE.get(line_id, [line_id]):
            body = await self._get("PCDRealTime", {"TrainLine": code})
            for row in body.get("value") or []:
                lvl = row.get("CrowdLevel")
                if lvl in CROWD_WORD:
                    levels[row["Station"]] = CROWD_WORD[lvl]
                    window = window or (row.get("StartTime"), row.get("EndTime"))
        out = {
            "source": "lta-crowd",
            "fetchedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
            "lineId": line_id,
            "window": window,
            "stations": levels,
            "simulated": False,
        }
        self._crowd_cache[line_id] = (now, out)
        return out

    async def bus_arrivals(self, stop_code: str, service_no: str | None = None) -> dict[str, Any]:
        params: dict[str, Any] = {"BusStopCode": stop_code}
        if service_no:
            params["ServiceNo"] = service_no
        body = await self._get("v3/BusArrival", params)
        now = datetime.now(timezone.utc)
        arrivals = []
        for svc in body.get("Services") or []:
            nexts = []
            for key in ("NextBus", "NextBus2", "NextBus3"):
                nb = svc.get(key) or {}
                eta = nb.get("EstimatedArrival")
                if not eta:
                    continue
                try:
                    t = datetime.fromisoformat(eta)
                    minutes = max(0, round((t - now).total_seconds() / 60))
                except ValueError:
                    minutes = None
                nexts.append({"minutes": minutes, "load": nb.get("Load"), "type": nb.get("Type"), "estimatedArrival": eta})
            arrivals.append({"serviceNo": svc.get("ServiceNo"), "operator": svc.get("Operator"), "next": nexts})
        return {
            "source": "lta-bus",
            "fetchedAt": now.astimezone().isoformat(timespec="seconds"),
            "stopCode": stop_code,
            "arrivals": arrivals,
            "simulated": False,
        }


def station_codes_to_line(codes: list[str]) -> str | None:
    """'NS1' → 'NSL' when the alert omits the line."""
    for c in codes:
        m = re.match(r"([A-Z]{2})\d", c)
        if m:
            return {"NS": "NSL", "EW": "EWL", "CC": "CCL", "DT": "DTL", "NE": "NEL", "TE": "TEL", "CG": "EWL"}.get(m.group(1))
    return None

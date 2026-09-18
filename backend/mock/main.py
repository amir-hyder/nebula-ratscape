"""NAVI local backend for the demo.

Holds the OneMap and LTA credentials, exposes normalised route candidates,
walking geometry, geocoding, train alerts and bus arrivals over HTTP so the
Flutter web app never touches a key. This is the local FastAPI server the
README describes; the production API will be the TypeScript service.

Run:  cd backend/mock && .venv/bin/uvicorn main:app --port 8080 --reload
"""
from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from lta import LtaClient, LtaError
from onemap import OneMapClient, OneMapError
from osm import OsmClient
from weather import WeatherClient

# Repository root .env is the documented location (see .env.example).
# backend/.env is still honoured so existing checkouts keep working.
_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(_ROOT / ".env")
load_dotenv(_ROOT / "backend" / ".env")

app = FastAPI(title="NAVI local backend", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

onemap = OneMapClient(os.getenv("ONEMAP_EMAIL"), os.getenv("ONEMAP_PASSWORD"))
lta = LtaClient(os.getenv("LTA_ACCOUNT_KEY"))
weather = WeatherClient()
osm = OsmClient()


class PointList(BaseModel):
    points: list[list[float]]


class Point(BaseModel):
    lat: float
    lon: float


class RouteRequest(BaseModel):
    origin: Point
    destination: Point
    date: str | None = Field(default=None, description="YYYY-MM-DD, default today")
    time: str | None = Field(default=None, description="HH:MM, default now")
    mode: str = Field(default="TRANSIT", pattern="^(TRANSIT|BUS|RAIL)$")
    numItineraries: int = Field(default=3, ge=1, le=3, description="OneMap allows at most 3")
    maxWalkDistance: int = Field(default=800, ge=100, le=3000)


def _when(date: str | None, time_: str | None) -> datetime:
    now = datetime.now()
    d = datetime.strptime(date, "%Y-%m-%d").date() if date else now.date()
    t = datetime.strptime(time_, "%H:%M").time() if time_ else now.time().replace(microsecond=0)
    return datetime.combine(d, t)


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok": True,
        "onemapConfigured": onemap.configured,
        "ltaConfigured": lta.configured,
        "time": datetime.now().astimezone().isoformat(timespec="seconds"),
    }


@app.post("/routes")
async def routes(req: RouteRequest) -> dict[str, Any]:
    """Public-transport itineraries from OneMap, normalised to RouteCandidate."""
    try:
        return await onemap.transit_routes(
            (req.origin.lat, req.origin.lon),
            (req.destination.lat, req.destination.lon),
            _when(req.date, req.time),
            mode=req.mode,
            num=req.numItineraries,
            max_walk_m=req.maxWalkDistance,
        )
    except OneMapError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/walk")
async def walk(
    start: str = Query(description="lat,lon"),
    end: str = Query(description="lat,lon"),
) -> dict[str, Any]:
    try:
        s = tuple(float(x) for x in start.split(","))
        e = tuple(float(x) for x in end.split(","))
        return await onemap.walk_route((s[0], s[1]), (e[0], e[1]))
    except OneMapError as ex:
        raise HTTPException(status_code=503, detail=str(ex)) from ex


@app.get("/geocode")
async def geocode(q: str) -> dict[str, Any]:
    try:
        return {"source": "onemap", "results": await onemap.geocode(q)}
    except OneMapError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/conditions/train-alerts")
async def train_alerts() -> dict[str, Any]:
    try:
        return await lta.train_alerts()
    except LtaError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/conditions/crowding")
async def crowding(line: str) -> dict[str, Any]:
    """LTA Station Crowd Density (real-time) for a NAVI line id (NSL, EWL, ...)."""
    try:
        return await lta.crowding(line.upper())
    except LtaError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/weather")
async def weather_now(lat: float, lon: float) -> dict[str, Any]:
    """data.gov.sg 2-hour nowcast for the nearest area plus nearest rainfall gauge."""
    try:
        return await weather.now(lat, lon)
    except Exception as e:  # network or schema
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.post("/osm/walk-features")
async def osm_walk_features(req: PointList) -> dict[str, Any]:
    """OSM crossings, steps, sheltered walkways and shelters along a walking leg."""
    try:
        return await osm.walk_features(req.points)
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/osm/safe-places")
async def osm_safe_places(lat: float, lon: float, radius: int = 600) -> dict[str, Any]:
    """OSM staffed places near a point: police, clinics, libraries, community centres, shops."""
    try:
        return await osm.safe_places(lat, lon, min(max(radius, 100), 1500))
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e)) from e


@app.get("/bus-arrivals")
async def bus_arrivals(stop: str, service: str | None = None) -> dict[str, Any]:
    try:
        return await lta.bus_arrivals(stop, service)
    except LtaError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

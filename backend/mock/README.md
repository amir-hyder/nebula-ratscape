# NAVI local backend (FastAPI)

Local proxy that keeps the OneMap and LTA DataMall credentials server-side and
serves normalised data to the Flutter web app. Testing and demo tool; the
production API remains the TypeScript service described in `docs/`.

```sh
cd backend/mock
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn main:app --port 8080 --reload
```

Reads `backend/.env` (`ONEMAP_EMAIL`, `ONEMAP_PASSWORD`, `LTA_ACCOUNT_KEY`).

| Endpoint | Source | Purpose |
| --- | --- | --- |
| `GET /health` | – | Which credentials are configured |
| `POST /routes` | OneMap `routingsvc/route` (pt) | Itineraries → `RouteCandidate[]` with legs, stop codes, decoded geometry, walk steps |
| `GET /walk?start=lat,lon&end=lat,lon` | OneMap (walk) | Walking geometry and instructions |
| `GET /geocode?q=` | OneMap search | Address → lat/lon |
| `GET /conditions/train-alerts` | LTA `TrainServiceAlerts` | Live status, affected segments, messages |
| `GET /bus-arrivals?stop=&service=` | LTA `v3/BusArrival` | Next buses at a stop |
| `GET /conditions/crowding?line=EWL` | LTA `PCDRealTime` | Station crowd level per station code, 10-minute cache |
| `GET /weather?lat=&lon=` | data.gov.sg 2-hour nowcast + rainfall | Nearest area forecast, nearest gauge reading, rain flag and advice |
| `POST /osm/walk-features` `{points}` | OpenStreetMap Overpass | Crossings, steps, sheltered walkways and shelters within 25 m of a walking polyline |
| `GET /osm/safe-places?lat=&lon=&radius=` | OpenStreetMap Overpass | Police, clinics, libraries, community centres, schools and convenience stores nearby |

Live responses carry `"simulated": false` or `"source": "onemap"`; the Flutter
app falls back to labelled offline fixtures when this server is unreachable.
Attribution: routes © OneMap / Singapore Land Authority; map data © OpenStreetMap contributors (ODbL); tiles © CARTO; weather © data.gov.sg; transport feeds © LTA DataMall. Overpass responses are cached under `.cache/osm` for 24 hours so the public instance is queried once per area.

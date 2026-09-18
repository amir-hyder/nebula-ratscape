# NAVI product spec

## Purpose and persona

NAVI helps a child make routine public transport journeys independently in Singapore. A parent saves arrival destinations and schedules; the child sees concise next steps. The prototype is a mobile-first web app intended for a browser URL. The watch is a watch-shaped web view, not a native watchOS app.

## Current prototype

Three entry modes use the same child and parent widgets and one in-memory demo state. The parent can add/edit destinations and recurrence (days, arrival time, buffer). The child selects a destination, starts a journey, advances through simulated stages, manually indicates leaving the vehicle, requests help, and explicitly confirms arrival. Parent status and in-app notifications update with those actions. Demo controls inject route changes, earlier departure, location error and no-route states. No data survives refresh.

Figma references: original watch design `https://www.figma.com/proto/jGzRfcOLEUkfUFVRSP0qtI/Untitled?node-id=17-40`; parent source is the user-supplied Figma Make export `Interactive Parent Interface Design/`. Parent screen hierarchy and teal/mint styling are adapted into Flutter. Singapore mock locations replace the export's Manchester examples. Any map illustration and external-data value must be labelled simulated.

## Intended journey rules

- A schedule stores destination, days, required arrival and buffer. It does not lock a route.
- Every route request uses the child's latest current location as origin. Mark stale or missing location.
- Monitor relevant scheduled and active journeys once per minute during a defined window, with central deduplication.
- OneMap provides route candidates and estimated journey durations, including estimated waiting. The test response's bus legs had `realTime: false`.
- LTA `v3/BusArrival` supplies current-stop bus ETAs and occupancy after the child starts. It is separate from journey duration planning.
- LTA `TrainServiceAlerts` is the primary structured train disruption source. Match `AffectedSegments` against remaining line, station segment, direction and time; parse `Message` separately.
- Notify the child only if their remaining journey is affected. Find/validate an alternative automatically; parent approval is not required.
- Meaningful departure changes should have a prominent clear alert and repeated small changes should be suppressed.
- Reroute from an actionable current position. A child already aboard cannot act on instructions that begin at the original origin.
- No precise Get Off instruction or stop countdown. Reaching Soon is approximate; the child taps “I’m off the bus/train” before final walk.
- Only explicit child confirmation creates an arrival event.

## Hackathon scope

The final submission needs real door-to-door planning, changed-condition response, an OpenStreetMap geospatial base with attribution, and phone-readable visualisation of original versus alternative route, affected section, crowding and time. The prototype's replaceable illustration is not a live OSM map. Planned events and weather must eventually influence advice. Label replayed disruptions as simulations. Store no actual child's personal location in a publicly accessible unauthenticated demo.

See `OPEN_DECISIONS.md` for unverified routing and policy decisions. No integration is claimed complete by this prototype.

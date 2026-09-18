# NAVI — write-up

## 1. The persona

**Maya is a nine-year-old primary school child who travels independently to
familiar places such as school, tuition and home.** She wears a watch but does
not carry a phone. She can follow a familiar route, but a disruption may leave
her unsure where to go next or how to reach her parent.

NAVI gives Maya one clear instruction at a time. If a disruption affects the
journey ahead, it finds an actionable alternative from her current position
without making her wait for parental approval. Maya can request help with one
tap, while her parent receives important journey updates. Maya marks when she
has left the vehicle and explicitly confirms her arrival.

## 2. Key features and direct benefit to Maya

- **Parent-approved places.** Maya's parent saves familiar destinations such
  as school, home and tuition. Maya chooses a place with one tap instead of
  entering an address or deciding where she is allowed to go.
- **Recurring arrival schedules.** Her parent sets the days, arrival time and
  buffer for a regular trip. NAVI shows Maya when to leave, based on the
  journey estimate, so she does not have to work backwards from a timetable.
  If a relevant delay is known before departure, the intended behaviour is a
  clear **Leave earlier** alert to Maya and an update to her parent, giving
  her time to set off before the disruption makes her late.
- **One step at a time on the watch.** Short instructions and a map show the
  next walk, stop, vehicle or transfer. Maya can focus on the immediate action
  rather than reading a full itinerary while moving through a station.
- **Useful live context.** OneMap supplies route options, while the map,
  bus-arrival information, rain and station crowding are translated into
  simple visual and written cues. Maya sees what matters at the next stop
  instead of having to interpret several transport feeds herself.
- **Condition-aware rerouting.** NAVI checks whether a disruption affects the
  part of Maya's route still ahead. When she can act, it selects an alternative
  from her current position without waiting for parental approval. An
  irrelevant alert is kept off her watch, reducing confusion.
- **Simple help and parent updates.** Maya can report that she is lost,
  frightened, unwell or has missed a stop without composing a message. Her
  parent sees the situation and can send a short reply, so Maya knows an
  adult has heard her.
- **Manual alighting and arrival confirmation.** NAVI says *reaching soon*
  instead of guessing the exact moment to get off. Maya marks when she is off
  the vehicle and confirms arrival herself. Her parent is not falsely told she
  has arrived just because a location estimate passed the destination.

The prototype demonstrates the scheduled leave time and a pre-departure
**Leave earlier** scenario using a simulated clock and an injected delay.
Alerts are in-app; there is no background scheduler, phone push delivery or
validated arrival-deadline search yet. In deployment, monitoring recurring
journeys and notifying Maya before she leaves would need a server-side
scheduler, fresh route and disruption data, and a delivery mechanism that
works when the web page is closed. Schedule-based estimation is deliberately
the last backend phase, after active-journey routing and rerouting are reliable.

## 3. Architecture

```
Flutter Web (one shared store, four views)
  ├─ engine/     decision logic, pure Dart, no Flutter imports
  ├─ services/   HTTP client, holds no credentials
  └─ four views: child watch · parent phone · combined · demo lab
        │
        ▼  HTTP
Python FastAPI (backend/mock) — holds the keys, makes no decisions
  ├─ OneMap        routing, walking routes, geocoding
  ├─ LTA DataMall  train alerts, station crowding, bus arrivals
  ├─ data.gov.sg   two-hour nowcast, rainfall gauges
  └─ OpenStreetMap Overpass, disk-cached
```

**The backend makes no decisions.** It holds credentials a browser cannot
safely hold, and it translates four incompatible formats into one shape. All
routing logic lives in the app.

That split is deliberate. `apps/web/lib/engine/reroute_engine.dart` has no
Flutter imports, so it is unit tested in isolation and can be lifted into the
TypeScript coordinator described in `docs/ARCHITECTURE.md` without touching any
UI. The provisional contracts in `backend/src/contracts/index.ts` predate this
build and the Dart models still mirror them.

The translation work is where most of the backend's code goes. OneMap returns
OpenTripPlanner-shaped itineraries; NAVI needs line ids that match LTA's
disruption feed, waiting times computed from the gaps between legs, decoded
polylines for the map and the turn detection, and station names short enough
for a watch face. The line codes differ between feeds, which the brief warns
about: the East-West line is `EW` in routing, `EWL` and `CGL` in crowding.
Everything maps through one table in `backend/mock/lta.py` and one in
`backend/mock/onemap.py`.

### The rerouting algorithm

Every condition runs through the same funnel, in `reroute_engine.dart`:

1. **Relevance.** Only the legs the child has not yet travelled are checked. A
   problem behind her, or on a line she never uses, is discarded silently.
2. **Threshold.** A delay below the alert threshold is recorded for the parent
   and never shown to the child.
3. **Kind.** Weather and crowding change advice, not the route.
4. **Actionable position.** If she is already aboard the affected vehicle, no
   route is offered, because she could not act on one. A closure becomes "get
   off at the next stop and wait for a staff member". A delay becomes "stay on".
5. **Re-plan.** Otherwise OneMap is queried again from where she is standing,
   or from the next stop if she is aboard something unaffected. Candidates are
   discarded if they start from a place she has passed, use something else
   currently disrupted, exceed her walking limit, or exceed her transfer limit.
6. **Score.** `travel minutes + (transfer penalty × changes) + (walking ÷ 2)`.
   In rain the walking term doubles instead of halving, so sheltered options win.
7. **Compare.** Against staying put, which is scored the same way with the delay
   added, or as infinite for a closure. Lower wins. If nothing survives, the
   child is told to stay where she is and the parent is alerted to call.

OneMap has no "avoid this line" parameter, so step 5 works around it by
re-querying from the child's position and, when every itinerary is still
affected, asking again in bus-only mode.

## 4. Assumptions

Stated plainly, because several are load-bearing:

- **The parent sets the destinations.** The child only ever chooses between
  saved places. She never types an address, and cannot travel somewhere the
  parent has not approved.
- **The child confirms her own arrival.** Nothing infers it from position. A
  geofence would produce false "she's safe" signals, which is the worst
  possible failure for this product.
- **Rerouting needs no parental approval.** A child at a bus stop cannot wait
  for an adult to read a notification. The parent is told, not asked.
- **Alighting is manual.** NAVI never says "get off now", because being wrong
  once would be worse than being vague every time. It says "reaching soon" and
  she taps when she is off.
- **Free bus and shuttle mitigations exist in the LTA feed** but we do not yet
  route onto them. See limitations.
- **The demo runs from a fixed home coordinate in Tampines.** Real deployment
  would need location permission and a policy for a child's location data,
  which we have deliberately not built.

## 5. Known limitations

- **The child's position is simulated.** NAVI never asks the browser for GPS.
  The blue dot moves along the real route geometry on a sped-up clock. Routes,
  maps, weather, crowding and alerts are live; location is not.
- **The watch is a watch-shaped web view**, not a wearable build. The brief asks
  for a web app, so this is in scope, but it is a mock of the form factor.
- **Offline behaviour is partial.** The brief asks what happens underground.
  The planned journey and its instructions are held in memory, so the child
  keeps seeing her next step with no signal, and a failed re-plan degrades to
  the last known candidates and says so in the trace. What is missing is a
  staleness indicator on the child's screen: she is not currently told that
  what she is looking at may be out of date. That is the first thing we would
  add.
- **The child-suitability limits are chosen, not validated.** Defaults are 15
  minutes maximum walk per leg, at most 2 transfers, a 5 minute alert
  threshold, and a 6 minute penalty per transfer. These come from judgement
  about what a nine-year-old can manage, not from testing with children. They
  are exposed as live controls in the demo dashboard precisely so a judge can
  change them and watch the ranking change. Treat the specific values as
  unproven.
- **No persistence and no authentication.** State resets on refresh. Nothing is
  stored server-side, which is also why no real child's location exists anywhere.
- **Scheduled departure alerts are simulated.** The demo calculates a leave-by
  time from the saved arrival time, buffer and route duration, and can replay
  a pre-departure delay that moves that time earlier. It does not monitor
  future journeys in the background or deliver a notification to a closed
  browser. Nor has the calculation been validated against OneMap's
  arrival-deadline search. This was deliberately deferred; see
  `docs/OPEN_DECISIONS.md`.
- **Line-code mapping is tested only against the lines our demo routes use.**
  The LRT mappings in particular are written from the brief's table, not
  verified against live responses.
- **Accessibility is partial.** Contrast was checked and no state relies on
  colour alone, since every crowding and alert state carries a word and a
  symbol. It has not been tested with a screen reader.
- **Free public bus and MRT shuttle mitigations are parsed but unused.** The
  LTA alert feed tells us where free boarding is active. Using it would improve
  the advice materially and we have not done it.

## 6. Numbers, and where they come from

The brief asks that any number says how it was arrived at.

| Claim | How to check it |
| --- | --- |
| 32 tests pass | `cd apps/web && flutter test` |
| Analyzer clean, and every commit builds on its own | `flutter analyze`; each commit was checked out into a worktree and analyzed |
| "Scores 57 versus 66" in the demo | One recorded run, Circle line delayed 15 minutes, child waiting at Paya Lebar. Both numbers come from the scoring function in §3 and are printed in the decision trace |
| OneMap returns at most 3 itineraries | API limit. `numItineraries` above 3 returns HTTP 400 |
| Cache lifetimes: token to expiry, weather 5 min, crowding 10 min, OSM 24 h | Chosen to match each source's own refresh rate. LTA publishes crowding every 10 minutes; the brief asks that Overpass not be queried in a loop |
| No credentials in the repository or its history | Every blob in the history was searched for the OneMap password and the LTA key. Zero hits |

The child-suitability constants in §5 are the one set of numbers with no
evidence behind them, and we would rather say so than imply otherwise.

# NAVI — write-up

## 1. The persona

**A primary school child, roughly seven to twelve, travelling alone, with a
parent as the second user.**

The brief invites teams to propose their own persona if they can justify it.
This one is a stricter case of Mdm Lim, the accessibility-constrained traveller
in §2.2, and it tightens every requirement in the same direction:

- The whole trip must be planned door to door before she leaves, because she
  cannot improvise a reroute on a platform.
- Every instruction must be one short line she can read while walking, with a
  picture. Not a list of options to weigh.
- She has no phone and cannot call anyone. Reaching an adult has to be one tap.
- Someone else needs to know when it goes wrong, immediately, without her
  having to explain it.

We chose it because it changes the product rather than the wording. An app for
Rachel can afford to say "NSL delays, consider alternatives" and let her decide.
An app for a nine-year-old standing at a bus stop cannot. That constraint is
what produced the two decisions we think are the interesting ones: rerouting
from the child's actual position rather than from her origin, and acting
without waiting for parental approval.

## 2. Architecture

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

## 3. Assumptions

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

## 4. Known limitations

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
- **Schedule-based time estimation is simulated.** Leave-by times and arrival
  deadlines are computed from the route length against a saved arrival time,
  not from an arrival-deadline search against OneMap's departure-time API. This
  was deliberately deferred; see `docs/OPEN_DECISIONS.md`.
- **Line-code mapping is tested only against the lines our demo routes use.**
  The LRT mappings in particular are written from the brief's table, not
  verified against live responses.
- **Accessibility is partial.** Contrast was checked and no state relies on
  colour alone, since every crowding and alert state carries a word and a
  symbol. It has not been tested with a screen reader.
- **Free public bus and MRT shuttle mitigations are parsed but unused.** The
  LTA alert feed tells us where free boarding is active. Using it would improve
  the advice materially and we have not done it.

## 5. Numbers, and where they come from

The brief asks that any number says how it was arrived at.

| Claim | How to check it |
| --- | --- |
| 32 tests pass | `cd apps/web && flutter test` |
| Analyzer clean, and every commit builds on its own | `flutter analyze`; each commit was checked out into a worktree and analyzed |
| "Scores 57 versus 66" in the demo | One recorded run, Circle line delayed 15 minutes, child waiting at Paya Lebar. Both numbers come from the scoring function in §2 and are printed in the decision trace |
| OneMap returns at most 3 itineraries | API limit. `numItineraries` above 3 returns HTTP 400 |
| Cache lifetimes: token to expiry, weather 5 min, crowding 10 min, OSM 24 h | Chosen to match each source's own refresh rate. LTA publishes crowding every 10 minutes; the brief asks that Overpass not be queried in a loop |
| No credentials in the repository or its history | Every blob in the history was searched for the OneMap password and the LTA key. Zero hits |

The child-suitability constants in §4 are the one set of numbers with no
evidence behind them, and we would rather say so than imply otherwise.

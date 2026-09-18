# Parallel backend work

Before implementation, agree on `JourneyRequest`, `RouteCandidate`, `Condition`, `JourneyDecision` and `JourneyEvent` in `backend/src/contracts/index.ts`, and keep dated simulated fixtures in `contracts/examples/`. Use ISO 8601 timestamps with timezone. Each member can test against mock outputs from the other modules.

1. **Routing/planning:** Own OneMap access, candidate normalisation, departure-time search for arrival deadlines, alternate candidate generation, suitability ranking and route geometry. Input `JourneyRequest`; output `RouteCandidate[]`.
2. **Conditions:** Own LTA train alerts, bus arrivals, planned works, crowding and weather, plus identifier mappings and feed freshness. Input candidates; output normalised `Condition[]` and a separate bus-arrival result.
3. **Journey coordination:** Own HTTP API, Firestore, schedules, child actions, alert thresholds, polling window and decision state. Combine candidate routes with relevant conditions into `JourneyDecision` and meaningful `JourneyEvent`s.

Integration gate: one real route, one irrelevant alert, one relevant train segment alert, a validated alternative meeting the arrival deadline, and a labelled replay scenario. Backend API and Firestore are not implemented by this scaffold.

## Implementation sequence

Build the three modules independently against shared mock fixtures, then integrate a basic active journey first: a real route from the child's current location, an irrelevant alert that causes no change, a relevant alert, and an actionable validated alternative. Keep the existing interface and provisional contracts during this phase.

Schedule-based time estimation is the **last backend phase**. Only after the active-journey flow works should routing implement arrival-deadline searches, the coordinator calculate leave-by times and buffers, and the team validate departure-change alerts. The arrival-deadline requirement in the integration gate above belongs to this final phase, not the first integration milestone.

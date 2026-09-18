# Architecture

```text
Flutter Web (child / parent / combined)
  └─ today: one in-memory DemoStore and simulated route map
  └─ later: HTTP API + shared journey state
       ├─ route planner → OneMap
       ├─ conditions → LTA, weather, crowding, planned events
       └─ coordinator → Firestore, decisions and alerts
```

The future TypeScript service will own keys and call external services. Firestore stores destinations, schedules, selected journey, stage and meaningful events. Polling responses and bus ETAs should normally be cached briefly instead of persisted every minute. Frontend widgets use domain concepts that can later be backed by API repositories.

The combined mode mounts the same child and parent widgets. Navigation state is separate; journey state is shared. A narrow viewport shows one interface at a time while preserving its state. Demo controls change shared state to exercise the interfaces.

The planned OSM map layer must show attribution and use a tile provider with appropriate terms. OneMap route data requires its own attribution. Confirm display terms and geometry in the live integration. Browser geolocation and background operation require separate design: the child web page cannot be assumed to report a fresh location after it closes.

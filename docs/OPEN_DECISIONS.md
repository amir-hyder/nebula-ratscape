# Decisions and checks still open

Priority note: implement schedule-based time estimation last. The existing prototype and contracts retain their simulated leave-time and ETA fields; defer live leave-by calculations, arrival-deadline search, arrival buffers, and departure-change alerts until the active-journey route and disruption flow is working.

- Prove an arrival-deadline search using OneMap's departure-time API and real returned itinerary timestamps.
- Determine how to obtain useful mixed-mode alternatives around a specific unavailable segment when the first OneMap candidates are all affected. Bus-only is a coarse fallback.
- Map OneMap service/station/direction identifiers to LTA affected segments with tested real samples.
- Set child-suitable limits for walking, transfers and delay, including when a simpler route outranks a faster one.
- Set default arrival buffer, alert threshold and repeat-suppression interval.
- Set scheduled-journey monitoring window and max accepted age of child location.
- Define actionable rerouting when already aboard.
- Decide how weather, crowding and planned events change recommendations rather than only decorate the UI.
- Verify OneMap geometry, display terms, OSM map integration and attribution together.
- Check external API quotas and Cloud project permissions for the intended polling load.
- Define the public prototype's privacy and write restrictions before storing any real family data.

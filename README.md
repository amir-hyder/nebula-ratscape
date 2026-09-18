# NAVI

NAVI is a Flutter Web prototype for the NEBULA X / LTA Smart Commuter Companion problem. It demonstrates a child's watch-style journey view, a parent's phone view, and a combined view with one shared mock state. All places, timing, maps, bus arrivals and notifications in this build are **simulated**.

## Run locally

Requirements: Flutter 3.47+ with web support and a modern browser. On macOS, `brew install --cask flutter` installs the SDK if needed.

```sh
cd ~/Desktop/navi/apps/web
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1
```

Open the localhost URL printed by Flutter in Chrome. If Chrome does not launch automatically, run `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080` and open `http://127.0.0.1:8080/` in a browser. The app must be served over HTTP: opening `web/index.html` or `build/web/index.html` with an editor's **Open in** button or a `file://` URL can show a blank page because Flutter's bootstrap and asset paths expect a web server.

For a release build: `flutter build web`. Flutter writes static files to `apps/web/build/web`. Preview that build with `cd build/web && python3 -m http.server 8080 --bind 127.0.0.1`, then open `http://127.0.0.1:8080/`. No API keys, backend server, Firebase project or login are needed for this prototype.

## Try the journey

Open **Combined demo** on a wide screen, or switch between Child and Parent on a phone. In the parent view, add or edit a destination and recurring arrival schedule. In the child view, choose a destination, start the journey, move through walking/waiting/onboard/reaching/final walk, then explicitly confirm arrival. Parent updates and notifications reflect child actions. Open the top-right **Demo controls** to simulate a relevant disruption, leaving earlier, help, unavailable location or no route. All demo events are local to the current browser session and reset on refresh.

## Project layout

- `apps/web/lib/demo_store.dart`: shared in-memory models and demo actions.
- `apps/web/lib/child_view.dart`: watch-style screens, adapted from original Figma design.
- `apps/web/lib/parent_view.dart`: phone screens, adapted from the supplied Figma Make export.
- `apps/web/lib/ui_kit.dart`: reusable colours, cards and map placeholder.
- `backend/src/modules/routing`: future route planning module (team member 1).
- `backend/src/modules/conditions`: future transport and weather feeds (team member 2).
- `backend/src/modules/journeys`: future journey coordinator and persistence (team member 3).
- `backend/src/contracts/index.ts` and `contracts/examples/`: provisional data contracts and demo example.
- `docs/`: product rules, architecture, team boundaries and unresolved decisions.
- `infrastructure/`: planned Google Cloud deployment.

The backend folders are scaffolds. There is no server, Firestore connection, scheduled polling or external API integration yet. `backend/.env` contains blank placeholders and is Git-ignored; `backend/.env.example` is tracked. Do not put credentials into Flutter assets or `--dart-define` values.

The parent export used Manchester example addresses. The Flutter demo uses Singapore public examples to match the hackathon context. The route map is a labelled illustration; it is designed to be replaced by an OSM-based implementation.

Future deployment: static Flutter Web on Firebase Hosting and a TypeScript API on Cloud Run with Firestore. See `infrastructure/README.md`. The prototype can also be hosted statically while the backend is absent.

## Backend implementation order

Keep the current interface and provisional contracts while building the backend. First complete current-location route planning for an active journey, condition matching, journey state, and a working relevant-disruption reroute. Implement schedule-based time estimation **last**: calculating when to leave, searching routes against a saved arrival deadline, applying the arrival buffer, and changing departure alerts. The current leave-time and ETA displays remain simulated until that later phase is implemented and verified. See `docs/TEAM_WORK_SPLIT.md` and `docs/OPEN_DECISIONS.md`.

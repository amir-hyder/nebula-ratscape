# Routing and planning

Owner 1: OneMap adapter, route normalisation, arrival deadline search, alternate candidates, route ranking, geometry. Consume `JourneyRequest`; return `RouteCandidate[]`. Test against mocked `Condition[]` before integration. Do not claim that OneMap can avoid a specified disrupted segment without proving it.

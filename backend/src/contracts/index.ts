/** Provisional API contract. Match contracts/examples before implementing modules. */
export type JourneyStage = 'idle' | 'walking' | 'waiting' | 'onboard' | 'reaching' | 'final_walk' | 'awaiting_confirmation' | 'arrived';
export type TransportMode = 'walk' | 'bus' | 'rail';
export interface LocationFix { latitude: number; longitude: number; observedAt: string; }
export interface JourneyRequest { journeyId: string; origin: LocationFix; destinationId: string; requiredArrival: string; arrivalBufferMinutes: number; }
export interface RouteLeg { mode: TransportMode; from: string; to: string; serviceId?: string; lineId?: string; direction?: string; stopIds?: string[]; stationIds?: string[]; startAt: string; endAt: string; geometry?: string; }
export interface RouteCandidate { id: string; source: 'onemap' | 'demo'; fetchedAt: string; departAt: string; arriveAt: string; legs: RouteLeg[]; estimated: boolean; }
export interface Condition { id: string; source: 'lta-train' | 'lta-bus' | 'weather' | 'crowding' | 'planned-event' | 'demo'; observedAt: string; validUntil?: string; lineIds?: string[]; stationIds?: string[]; direction?: string; severity: 'info' | 'caution' | 'disruption'; summary: string; simulated: boolean; }
export interface JourneyDecision { journeyId: string; stage: JourneyStage; route?: RouteCandidate; leaveAt?: string; estimatedArrival?: string; action: 'keep' | 'leave_earlier' | 'reroute' | 'no_route' | 'refresh_location' | 'help'; reason: string; affectedConditionIds: string[]; decidedAt: string; simulated: boolean; }
export interface JourneyEvent { id: string; journeyId: string; type: 'started' | 'route_changed' | 'help_requested' | 'arrival_confirmed'; occurredAt: string; message: string; simulated: boolean; }

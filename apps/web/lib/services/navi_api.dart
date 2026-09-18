import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/conditions.dart';
import '../models/route_models.dart';

/// Live train-alert snapshot from LTA via the local backend.
class TrainAlerts {
  const TrainAlerts({required this.status, required this.segments, required this.messages, required this.fetchedAt});
  final String status; // normal | disrupted
  final List<AffectedSegment> segments;
  final List<String> messages;
  final String fetchedAt;
}

class AffectedSegment {
  const AffectedSegment({required this.lineId, required this.stationCodes, this.direction});
  final String lineId;
  final List<String> stationCodes;
  final String? direction;
}

class BusArrival {
  const BusArrival({required this.serviceNo, required this.minutes, required this.loads});
  final String serviceNo;
  final List<int> minutes;
  final List<String> loads; // SEA, SDA, LSD
}

/// Thin client for backend/mock. The Flutter app never holds API keys.
class NaviApi {
  NaviApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? const String.fromEnvironment('NAVI_API', defaultValue: 'http://127.0.0.1:8080'),
      _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 25);

  Future<bool> health() async {
    try {
      final r = await _client.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
      return r.statusCode == 200 && (jsonDecode(r.body)['onemapConfigured'] == true);
    } catch (_) {
      return false;
    }
  }

  Future<List<RouteCandidate>> routes({
    required LatLng origin,
    required LatLng destination,
    required String destinationId,
    int? departMinutes,
    String mode = 'TRANSIT',
    int numItineraries = 3,
    int maxWalkDistance = 800,
  }) async {
    final body = {
      'origin': {'lat': origin.lat, 'lon': origin.lon},
      'destination': {'lat': destination.lat, 'lon': destination.lon},
      if (departMinutes != null) 'time': hhmm(departMinutes),
      'mode': mode,
      'numItineraries': numItineraries,
      'maxWalkDistance': maxWalkDistance,
    };
    final r = await _client
        .post(Uri.parse('$baseUrl/routes'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('routes ${r.statusCode}: ${r.body}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final out = [
      for (final c in j['candidates'] as List)
        RouteCandidate.fromJson(c as Map<String, dynamic>, destinationId: destinationId),
    ];
    return out;
  }

  Future<TrainAlerts> trainAlerts() async {
    final r = await _client.get(Uri.parse('$baseUrl/conditions/train-alerts')).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('train alerts ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return TrainAlerts(
      status: j['status'] as String,
      fetchedAt: j['fetchedAt'] as String,
      segments: [
        for (final s in j['affectedSegments'] as List)
          AffectedSegment(
            lineId: (s['lineId'] ?? '') as String,
            direction: s['direction'] as String?,
            stationCodes: [for (final c in (s['stationCodes'] ?? []) as List) c as String],
          ),
      ],
      messages: [for (final m in j['messages'] as List) (m['content'] ?? '') as String],
    );
  }

  Future<List<BusArrival>> busArrivals(String stopCode, {String? service}) async {
    final uri = Uri.parse('$baseUrl/bus-arrivals').replace(queryParameters: {'stop': stopCode, 'service': ?service});
    final r = await _client.get(uri).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('bus arrivals ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return [
      for (final a in j['arrivals'] as List)
        BusArrival(
          serviceNo: a['serviceNo'] as String,
          minutes: [for (final n in a['next'] as List) ?(n['minutes'] as num?)?.round()],
          loads: [for (final n in a['next'] as List) (n['load'] ?? '') as String],
        ),
    ];
  }

  Future<WeatherNow> weather(LatLng at) async {
    final r = await _client
        .get(Uri.parse('$baseUrl/weather').replace(queryParameters: {'lat': '${at.lat}', 'lon': '${at.lon}'}))
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('weather ${r.statusCode}');
    return WeatherNow.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<OsmFeature>> walkFeatures(List<LatLng> points) async {
    final r = await _client
        .post(
          Uri.parse('$baseUrl/osm/walk-features'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'points': [for (final p in points) p.toJson()]}),
        )
        .timeout(const Duration(seconds: 50));
    if (r.statusCode != 200) throw Exception('walk features ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return [for (final f in j['features'] as List) OsmFeature.fromJson(f as Map<String, dynamic>)];
  }

  Future<List<OsmFeature>> safePlaces(LatLng at, {int radius = 600}) async {
    final r = await _client
        .get(Uri.parse('$baseUrl/osm/safe-places').replace(queryParameters: {'lat': '${at.lat}', 'lon': '${at.lon}', 'radius': '$radius'}))
        .timeout(const Duration(seconds: 50));
    if (r.statusCode != 200) throw Exception('safe places ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return [for (final f in j['features'] as List) OsmFeature.fromJson(f as Map<String, dynamic>)];
  }

  Future<StationCrowding> crowding(String lineId) async {
    final r = await _client
        .get(Uri.parse('$baseUrl/conditions/crowding').replace(queryParameters: {'line': lineId}))
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('crowding ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StationCrowding(
      lineId: lineId,
      fetchedAt: (j['fetchedAt'] ?? '') as String,
      levels: {
        for (final e in (j['stations'] as Map<String, dynamic>).entries) e.key: CrowdLevelX.parse(e.value as String?),
      },
    );
  }

  Future<LatLng?> geocode(String query) async {
    final r = await _client
        .get(Uri.parse('$baseUrl/geocode').replace(queryParameters: {'q': query}))
        .timeout(_timeout);
    if (r.statusCode != 200) return null;
    final results = (jsonDecode(r.body) as Map<String, dynamic>)['results'] as List;
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    return LatLng((first['lat'] as num).toDouble(), (first['lon'] as num).toDouble());
  }
}

// Live condition models: weather (data.gov.sg), OpenStreetMap features and
// LTA station crowding. All carry their source so the UI can label them.

import '../engine/geo.dart';

class WeatherNow {
  const WeatherNow({
    required this.area,
    required this.forecast,
    required this.rainfallMm,
    required this.raining,
    required this.heavy,
    required this.advice,
    required this.validPeriod,
    required this.fetchedAt,
  });
  final String area;
  final String forecast;
  final double rainfallMm;
  final bool raining;
  final bool heavy;
  final String advice;
  final String validPeriod;
  final String fetchedAt;

  String get emoji => heavy ? '⛈️' : raining ? '🌧️' : forecast.toLowerCase().contains('cloud') ? '⛅' : '☀️';

  /// One line for the watch.
  String get childLine => heavy
      ? 'Heavy rain in $area. Umbrella and shelter.'
      : raining
      ? 'Rain in $area. Bring your umbrella.'
      : '$forecast in $area.';

  factory WeatherNow.fromJson(Map<String, dynamic> j) => WeatherNow(
    area: (j['area'] ?? 'Singapore') as String,
    forecast: (j['forecast'] ?? 'Unknown') as String,
    rainfallMm: ((j['rainfallMm'] ?? 0) as num).toDouble(),
    raining: j['raining'] == true,
    heavy: j['heavy'] == true,
    advice: (j['advice'] ?? '') as String,
    validPeriod: (j['validPeriod'] ?? '') as String,
    fetchedAt: (j['fetchedAt'] ?? '') as String,
  );
}

/// A point of interest from OpenStreetMap (© OpenStreetMap contributors).
class OsmFeature {
  const OsmFeature({required this.kind, required this.label, required this.at, this.name, this.distanceM});
  final String kind; // crossing, steps, covered, shelter, police, clinic, ...
  final String label;
  final String? name;
  final LatLng at;
  final int? distanceM;

  String get emoji => switch (kind) {
    'crossing' => '🚸',
    'steps' => '🪜',
    'covered' => '⛱️',
    'shelter' => '⛱️',
    'police' => '👮',
    'clinic' || 'hospital' => '🏥',
    'library' => '📚',
    'community_centre' => '🏢',
    'school' => '🏫',
    'convenience' => '🏪',
    'place_of_worship' => '🛐',
    'fire_station' => '🚒',
    _ => '📍',
  };

  factory OsmFeature.fromJson(Map<String, dynamic> j) => OsmFeature(
    kind: (j['kind'] ?? 'place') as String,
    label: (j['label'] ?? '') as String,
    name: j['name'] as String?,
    at: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
    distanceM: (j['distanceM'] as num?)?.round(),
  );
}

enum CrowdLevel { low, moderate, high, unknown }

extension CrowdLevelX on CrowdLevel {
  static CrowdLevel parse(String? s) => switch (s) {
    'low' || 'l' => CrowdLevel.low,
    'moderate' || 'm' => CrowdLevel.moderate,
    'high' || 'h' => CrowdLevel.high,
    _ => CrowdLevel.unknown,
  };

  /// Three-level scale, never colour alone.
  String get word => switch (this) {
    CrowdLevel.low => 'Not crowded',
    CrowdLevel.moderate => 'Quite busy',
    CrowdLevel.high => 'Very crowded',
    CrowdLevel.unknown => 'No crowd data',
  };
  String get emoji => switch (this) {
    CrowdLevel.low => '🟢',
    CrowdLevel.moderate => '🟡',
    CrowdLevel.high => '🔴',
    CrowdLevel.unknown => '⚪',
  };
  int get colour => switch (this) {
    CrowdLevel.low => 0xFF16A34A,
    CrowdLevel.moderate => 0xFFB66711,
    CrowdLevel.high => 0xFFC83F43,
    CrowdLevel.unknown => 0xFF667085,
  };
}

class StationCrowding {
  const StationCrowding({required this.lineId, required this.levels, required this.fetchedAt});
  final String lineId;
  final Map<String, CrowdLevel> levels; // station code → level
  final String fetchedAt;
  CrowdLevel at(String? stationCode) => levels[stationCode] ?? CrowdLevel.unknown;
}

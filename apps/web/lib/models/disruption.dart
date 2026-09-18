import 'route_models.dart';

/// Kinds of condition the dashboard can inject. Mirrors `Condition.source`
/// and `severity` in the backend contract, but simplified for the demo.
enum DisruptionKind { delay, closure, crowding, weather }

class Disruption {
  Disruption({
    required this.id,
    required this.kind,
    required this.rawInput,
    this.lineId,
    this.serviceNo,
    this.stations = const [],
    this.delayMinutes = 0,
    required this.issuedAtMinutes,
    this.simulated = true,
  });
  final String id;
  final DisruptionKind kind;
  final String rawInput;
  final String? lineId;
  final String? serviceNo;
  /// Affected stations/stops. Empty means the whole line/service.
  final List<String> stations;
  final int delayMinutes;
  final int issuedAtMinutes;
  final bool simulated;

  bool get isWholeNetwork => lineId == null && serviceNo == null;

  String get targetLabel {
    if (lineId != null) return '$lineId line';
    if (serviceNo != null) return 'Bus $serviceNo';
    return 'All journeys';
  }

  String get kindLabel => switch (kind) {
    DisruptionKind.delay => 'Delayed $delayMinutes min',
    DisruptionKind.closure => 'Not running',
    DisruptionKind.crowding => 'Very crowded',
    DisruptionKind.weather => 'Heavy rain',
  };

  String get summary {
    final where = stations.isEmpty
        ? ''
        : ' between ${stations.first} and ${stations.last}';
    return '$targetLabel · $kindLabel$where';
  }

  /// Does this condition touch [leg]? Weather touches walking legs only.
  bool affects(RouteLeg leg) {
    if (kind == DisruptionKind.weather) return leg.mode == LegMode.walk;
    if (lineId != null) {
      if (leg.mode != LegMode.rail || leg.lineId != lineId) return false;
    } else if (serviceNo != null) {
      if (leg.mode != LegMode.bus || leg.serviceNo != serviceNo) return false;
    } else {
      return false;
    }
    if (stations.isEmpty) return true;
    return leg.stops.any(stations.contains);
  }
}

/// Turns operator phrases such as "red line delayed 10 min" or
/// "bus 10 not running" into a structured [Disruption]. Returns null when
/// no line, bus or weather word is recognised.
class DisruptionParser {
  DisruptionParser({required this.lines, required this.knownStations});
  final List<TransitLine> lines;
  final List<String> knownStations;

  Disruption? parse(String input, {required int nowMinutes}) {
    final text = input.toLowerCase().trim();
    if (text.isEmpty) return null;

    String? lineId;
    for (final line in lines) {
      final matches = [
        '${line.colourName} line',
        line.colourName,
        line.id.toLowerCase(),
        line.name.toLowerCase(),
        ...line.aliases,
      ];
      if (matches.any((alias) => _containsWord(text, alias))) {
        lineId = line.id;
        break;
      }
    }

    String? serviceNo;
    final bus = RegExp(r'(?:bus|service)\s*(\d+[a-z]?)').firstMatch(text);
    if (bus != null) serviceNo = bus.group(1)!.toUpperCase();

    final weather = RegExp(r'rain|storm|thunder|flood|haze|lightning')
        .hasMatch(text);
    if (lineId == null && serviceNo == null && !weather) return null;

    final kind = weather
        ? DisruptionKind.weather
        : RegExp(r'closed|closure|suspend|not running|no service|breakdown|broke down|stopped|down\b')
              .hasMatch(text)
        ? DisruptionKind.closure
        : RegExp(r'crowd|packed|full|busy').hasMatch(text)
        ? DisruptionKind.crowding
        : DisruptionKind.delay;

    final minutesMatch = RegExp(r'(\d+)\s*(?:min|mins|minutes|m\b)').firstMatch(text);
    var minutes = minutesMatch == null ? 0 : int.parse(minutesMatch.group(1)!);
    if (kind == DisruptionKind.delay && minutes == 0) minutes = 15;

    final stations = <String>[];
    for (final station in knownStations) {
      if (_containsWord(text, station.toLowerCase())) stations.add(station);
    }

    return Disruption(
      id: 'd-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      rawInput: input.trim(),
      lineId: lineId,
      serviceNo: serviceNo,
      stations: stations,
      delayMinutes: minutes,
      issuedAtMinutes: nowMinutes,
    );
  }

  static bool _containsWord(String text, String phrase) {
    final escaped = RegExp.escape(phrase);
    return RegExp('(^|[^a-z])$escaped([^a-z]|\$)').hasMatch(text);
  }
}

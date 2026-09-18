import '../engine/geo.dart';
import '../models/route_models.dart';

/// A small simulated slice of Singapore's network. Real stop sequences and
/// timings will come from OneMap; this fixture only needs to be plausible
/// enough to demonstrate relevance matching and rerouting.
abstract final class DemoNetwork {
  static const lines = <TransitLine>[
    TransitLine(
      id: 'NSL',
      name: 'North-South Line',
      colourName: 'red',
      colour: 0xFFD42E12,
      aliases: ['north south', 'north-south', 'ns line'],
    ),
    TransitLine(
      id: 'EWL',
      name: 'East-West Line',
      colourName: 'green',
      colour: 0xFF009645,
      aliases: ['east west', 'east-west', 'ew line'],
    ),
    TransitLine(
      id: 'CCL',
      name: 'Circle Line',
      colourName: 'orange',
      colour: 0xFFFA9E0D,
      aliases: ['yellow line', 'yellow', 'circle'],
    ),
    TransitLine(
      id: 'DTL',
      name: 'Downtown Line',
      colourName: 'blue',
      colour: 0xFF005EC4,
      aliases: ['downtown'],
    ),
    TransitLine(
      id: 'NEL',
      name: 'North East Line',
      colourName: 'purple',
      colour: 0xFF9900AA,
      aliases: ['north east', 'north-east', 'ne line'],
    ),
    TransitLine(
      id: 'TEL',
      name: 'Thomson-East Coast Line',
      colourName: 'brown',
      colour: 0xFF9D5B25,
      aliases: ['thomson', 'thomson-east coast', 'east coast'],
    ),
  ];

  static TransitLine? line(String? id) {
    for (final l in lines) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Approximate coordinates for fixture places, so the offline demo can
  /// still draw a map and a walking path. Simulated.
  static const coords = <String, LatLng>{
    'Home': LatLng(1.3530, 103.9450),
    'Tampines': LatLng(1.3533, 103.9452),
    'Tampines Int': LatLng(1.3541, 103.9431),
    'Tampines St 21': LatLng(1.3516, 103.9491),
    'Tampines St 22': LatLng(1.3562, 103.9488),
    'School': LatLng(1.3521, 103.9502),
    'Blk 201': LatLng(1.3532, 103.9468),
    'Blk 230': LatLng(1.3524, 103.9481),
    'Blk 138': LatLng(1.3548, 103.9460),
    'Blk 156': LatLng(1.3556, 103.9475),
    'Simei': LatLng(1.3432, 103.9534),
    'Simei Rd': LatLng(1.3440, 103.9520),
    'Tanah Merah': LatLng(1.3272, 103.9464),
    'Bedok': LatLng(1.3240, 103.9300),
    'Bedok North': LatLng(1.3300, 103.9340),
    'Bedok Int': LatLng(1.3247, 103.9298),
    'Bedok Reservoir': LatLng(1.3360, 103.9320),
    'Tuition': LatLng(1.3258, 103.9339),
    'Kembangan': LatLng(1.3210, 103.9130),
    'Eunos': LatLng(1.3197, 103.9032),
    'Paya Lebar': LatLng(1.3177, 103.8925),
    'MacPherson': LatLng(1.3266, 103.8900),
    'Tai Seng': LatLng(1.3358, 103.8878),
    'Bartley': LatLng(1.3426, 103.8797),
    'Serangoon': LatLng(1.3497, 103.8734),
    'Hougang': LatLng(1.3713, 103.8924),
    'Lorong Chuan': LatLng(1.3516, 103.8641),
    'Bishan': LatLng(1.3512, 103.8485),
    'Bishan Int': LatLng(1.3505, 103.8490),
    'Blk 401': LatLng(1.3600, 103.8480),
    'Ang Mo Kio': LatLng(1.3699, 103.8496),
    'Ang Mo Kio Int': LatLng(1.3695, 103.8470),
    'Grandma': LatLng(1.3691, 103.8454),
    'Destination': LatLng(1.3258, 103.9339),
  };

  static LatLng? coordOf(String name) => coords[name];

  /// Gives fixture legs a plausible geometry: stops joined in order, and an
  /// L-shaped path for walks, so the 3D navigation works offline.
  static RouteCandidate hydrate(RouteCandidate c) {
    if (c.legs.every((l) => l.hasGeometry)) return c;
    return c.copyWith(
      legs: [
        for (final leg in c.legs)
          leg.hasGeometry ? leg : _withGeometry(leg),
      ],
    );
  }

  static RouteLeg _withGeometry(RouteLeg leg) {
    final from = leg.fromLatLng ?? coords[leg.from] ?? coords['Home']!;
    final to = leg.toLatLng ?? coords[leg.to] ?? from;
    final pts = <LatLng>[from];
    if (leg.isTransit) {
      for (final s in leg.stops.skip(1).take(leg.stops.length - 2)) {
        final p = coords[s];
        if (p != null) pts.add(p);
      }
    } else {
      // Two bends so there is always a turn to announce.
      pts.add(LatLng(from.lat + (to.lat - from.lat) * .45, from.lon));
      pts.add(LatLng(from.lat + (to.lat - from.lat) * .45, from.lon + (to.lon - from.lon) * .7));
      pts.add(LatLng(to.lat, from.lon + (to.lon - from.lon) * .7));
    }
    pts.add(to);
    return leg.copyWith(points: pts, fromLatLng: from, toLatLng: to, distanceM: Geo.cumulative(pts).last.round());
  }

  static const stations = <String>[
    'Tampines',
    'Simei',
    'Tanah Merah',
    'Bedok',
    'Kembangan',
    'Eunos',
    'Paya Lebar',
    'MacPherson',
    'Tai Seng',
    'Bartley',
    'Serangoon',
    'Lorong Chuan',
    'Bishan',
    'Braddell',
    'Ang Mo Kio',
    'Tampines East',
    'Upper Changi',
    'Expo',
    'Tampines Int',
    'Bedok Int',
    'Ang Mo Kio Int',
    'Bishan Int',
    'Pasir Ris',
    'Aljunied',
    'Kallang',
    'Lavender',
    'Bugis',
    'City Hall',
    'Raffles Place',
    'Dhoby Ghaut',
    'Somerset',
    'Orchard',
    'Newton',
    'Novena',
    'Toa Payoh',
    'Braddell',
    'Yio Chu Kang',
    'Yishun',
    'Woodlands',
    'Jurong East',
    'Clementi',
    'Buona Vista',
    'Outram Park',
    'Chinatown',
    'HarbourFront',
    'Little India',
    'Botanic Gardens',
    'Stevens',
    'Caldecott',
    'Marina Bay',
    'Bayfront',
    'Promenade',
    'Esplanade',
    'Nicoll Highway',
    'Stadium',
    'Mountbatten',
    'Dakota',
    'Expo',
    'Changi Airport',
    'Bedok North',
    'Bedok Reservoir',
    'Kaki Bukit',
    'Ubi',
    'Geylang Bahru',
    'Bendemeer',
    'Jalan Besar',
    'Rochor',
    'Punggol',
    'Sengkang',
    'Buangkok',
    'Kovan',
    'Potong Pasir',
    'Boon Keng',
    'Farrer Park',
    'Clarke Quay',
  ];

  /// Candidate routes per destination, from the child's simulated current
  /// location (Tampines Central). Ordered by the planner's default choice.
  static List<RouteCandidate> candidatesFor(String destinationId) =>
      switch (destinationId) {
        'school' => _school,
        'tuition' => _tuition,
        'grandma' => _grandma,
        'home' => _home,
        _ => _generic(destinationId),
      };

  static const _school = <RouteCandidate>[
    RouteCandidate(
      id: 'school-bus10',
      destinationId: 'school',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines Int', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '10',
          from: 'Tampines Int',
          to: 'Tampines St 21',
          stops: ['Tampines Int', 'Blk 201', 'Blk 230', 'Tampines St 21'],
          minutes: 12,
          waitMinutes: 3,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Tampines St 21', to: 'School', minutes: 4),
      ],
    ),
    RouteCandidate(
      id: 'school-bus291',
      destinationId: 'school',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines Int', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '291',
          from: 'Tampines Int',
          to: 'Tampines St 22',
          stops: ['Tampines Int', 'Blk 138', 'Blk 156', 'Tampines St 22'],
          minutes: 15,
          waitMinutes: 5,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Tampines St 22', to: 'School', minutes: 3),
      ],
    ),
    RouteCandidate(
      id: 'school-walk',
      destinationId: 'school',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'School', minutes: 19),
      ],
    ),
  ];

  static const _tuition = <RouteCandidate>[
    RouteCandidate(
      id: 'tuition-ewl',
      destinationId: 'tuition',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines', minutes: 5),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'EWL',
          from: 'Tampines',
          to: 'Bedok',
          stops: ['Tampines', 'Simei', 'Tanah Merah', 'Bedok'],
          minutes: 10,
          waitMinutes: 3,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Bedok', to: 'Tuition', minutes: 4),
      ],
    ),
    RouteCandidate(
      id: 'tuition-bus10',
      destinationId: 'tuition',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines Int', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '10',
          from: 'Tampines Int',
          to: 'Bedok Int',
          stops: ['Tampines Int', 'Simei Rd', 'Bedok North', 'Bedok Int'],
          minutes: 25,
          waitMinutes: 4,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Bedok Int', to: 'Tuition', minutes: 3),
      ],
    ),
  ];

  /// Deliberately rail-heavy so the "red line delayed" demo has teeth.
  static const _grandma = <RouteCandidate>[
    RouteCandidate(
      id: 'grandma-rail',
      destinationId: 'grandma',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines', minutes: 5),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'EWL',
          from: 'Tampines',
          to: 'Paya Lebar',
          stops: ['Tampines', 'Simei', 'Tanah Merah', 'Bedok', 'Kembangan', 'Eunos', 'Paya Lebar'],
          minutes: 14,
          waitMinutes: 3,
        ),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'CCL',
          from: 'Paya Lebar',
          to: 'Bishan',
          stops: ['Paya Lebar', 'MacPherson', 'Tai Seng', 'Bartley', 'Serangoon', 'Lorong Chuan', 'Bishan'],
          minutes: 13,
          waitMinutes: 4,
        ),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'NSL',
          from: 'Bishan',
          to: 'Ang Mo Kio',
          stops: ['Bishan', 'Ang Mo Kio'],
          minutes: 3,
          waitMinutes: 3,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Ang Mo Kio', to: 'Grandma', minutes: 5),
      ],
    ),
    RouteCandidate(
      id: 'grandma-rail-bus88',
      destinationId: 'grandma',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines', minutes: 5),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'EWL',
          from: 'Tampines',
          to: 'Paya Lebar',
          stops: ['Tampines', 'Simei', 'Tanah Merah', 'Bedok', 'Kembangan', 'Eunos', 'Paya Lebar'],
          minutes: 14,
          waitMinutes: 3,
        ),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'CCL',
          from: 'Paya Lebar',
          to: 'Bishan',
          stops: ['Paya Lebar', 'MacPherson', 'Tai Seng', 'Bartley', 'Serangoon', 'Lorong Chuan', 'Bishan'],
          minutes: 13,
          waitMinutes: 4,
        ),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '88',
          from: 'Bishan Int',
          to: 'Ang Mo Kio Int',
          stops: ['Bishan Int', 'Blk 401', 'Ang Mo Kio Int'],
          minutes: 10,
          waitMinutes: 5,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Ang Mo Kio Int', to: 'Grandma', minutes: 3),
      ],
    ),
    RouteCandidate(
      id: 'grandma-bus22',
      destinationId: 'grandma',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines Int', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '22',
          from: 'Tampines Int',
          to: 'Ang Mo Kio Int',
          stops: ['Tampines Int', 'Bedok Reservoir', 'Hougang', 'Ang Mo Kio Int'],
          minutes: 58,
          waitMinutes: 6,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Ang Mo Kio Int', to: 'Grandma', minutes: 4),
      ],
    ),
  ];

  static const _home = <RouteCandidate>[
    RouteCandidate(
      id: 'home-bus10',
      destinationId: 'home',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'School', to: 'Tampines St 21', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '10',
          from: 'Tampines St 21',
          to: 'Tampines Int',
          stops: ['Tampines St 21', 'Blk 230', 'Blk 201', 'Tampines Int'],
          minutes: 12,
          waitMinutes: 3,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Tampines Int', to: 'Home', minutes: 4),
      ],
    ),
    RouteCandidate(
      id: 'home-walk',
      destinationId: 'home',
      legs: [
        RouteLeg(mode: LegMode.walk, from: 'School', to: 'Home', minutes: 19),
      ],
    ),
  ];

  static List<RouteCandidate> _generic(String destinationId) => [
    RouteCandidate(
      id: '$destinationId-bus10',
      destinationId: destinationId,
      legs: const [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines Int', minutes: 4),
        RouteLeg(
          mode: LegMode.bus,
          serviceNo: '10',
          from: 'Tampines Int',
          to: 'Bedok Int',
          stops: ['Tampines Int', 'Simei Rd', 'Bedok North', 'Bedok Int'],
          minutes: 20,
          waitMinutes: 4,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Bedok Int', to: 'Destination', minutes: 5),
      ],
    ),
    RouteCandidate(
      id: '$destinationId-ewl',
      destinationId: destinationId,
      legs: const [
        RouteLeg(mode: LegMode.walk, from: 'Home', to: 'Tampines', minutes: 5),
        RouteLeg(
          mode: LegMode.rail,
          lineId: 'EWL',
          from: 'Tampines',
          to: 'Bedok',
          stops: ['Tampines', 'Simei', 'Tanah Merah', 'Bedok'],
          minutes: 10,
          waitMinutes: 3,
        ),
        RouteLeg(mode: LegMode.walk, from: 'Bedok', to: 'Destination', minutes: 6),
      ],
    ),
  ];
}

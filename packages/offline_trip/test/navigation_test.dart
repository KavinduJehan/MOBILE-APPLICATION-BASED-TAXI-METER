import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:offline_trip/src/navigation_graph.dart';
import 'package:offline_trip/src/navigation_screen.dart';
import 'package:offline_trip/src/navigation_service.dart';

NavigationGraph fixture({
  bool oneWay = false,
  bool restricted = false,
  bool only = false,
  bool uTurn = false,
}) {
  final coords = [
    6900000,
    79860000,
    6900000,
    79861000,
    6901000,
    79861000,
    6901000,
    79860000,
  ];
  // A-B-C is the short route; A-D-C is the alternative.
  final adjacency = oneWay
      ? [
          [(1, 0)],
          <(int, int)>[],
          <(int, int)>[],
          <(int, int)>[],
        ]
      : [
          [(1, 0), (3, 2)],
          [(0, 0), (2, 1)],
          [(1, 1), (3, 3)],
          [(0, 2), (2, 3)],
        ];
  final starts = [0], targets = <int>[], roads = <int>[], lengths = <int>[];
  for (final outgoing in adjacency) {
    for (final edge in outgoing) {
      targets.add(edge.$1);
      roads.add(edge.$2);
      lengths.add(edge.$2 >= 2 ? 20000 : 11100);
    }
    starts.add(targets.length);
  }
  final metadata = {
    'cellE6': 20000,
    'cells': [
      [345, 3993, 0, 4],
    ],
    'roads': [
      ['Main', 2, 40, 3],
      ['Cross', 2, 40, 3],
      ['Detour', 6, 20, 3],
      ['Return', 6, 20, 3],
    ],
    'places': [
      ['Colombo', 6900000, 79860000, 'city', 'කොළඹ'],
    ],
    'restrictions': uTurn
        ? [
            [
              1,
              0,
              [0],
              'no_u_turn',
            ],
          ]
        : restricted
        ? [
            [
              1,
              0,
              [1],
              only ? 'only_straight_on' : 'no_left_turn',
            ],
          ]
        : [],
  };
  List<int> json = utf8.encode(jsonEncode(metadata));
  json = [...json, ...List.filled((-json.length) % 4, 32)];
  final header = ByteData(24)
    ..setUint32(8, 4, Endian.little)
    ..setUint32(12, targets.length, Endian.little)
    ..setUint32(16, json.length, Endian.little)
    ..setUint32(20, 1, Endian.little);
  header.buffer.asUint8List().setRange(0, 8, [...ascii.encode('RDXNAV1'), 0]);
  final builder = BytesBuilder()
    ..add(header.buffer.asUint8List())
    ..add(json);
  for (final values in [coords, starts, targets, lengths, roads]) {
    final block = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      block.setInt32(i * 4, values[i], Endian.little);
    }
    builder.add(block.buffer.asUint8List());
  }
  return NavigationGraph(builder.takeBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('partial-edge route and reverse one-way rejection', () {
    final graph = fixture(oneWay: true);
    final route = graph.route(6.9, 79.86025, 6.9, 79.86075, 'car');
    expect(route['meters'], closeTo(55.5, .1));
    expect(
      () => graph.route(6.9, 79.86075, 6.9, 79.86025, 'car'),
      throwsFormatException,
    );
  });
  test('turn restriction forces a legal detour', () {
    final short = fixture().route(6.9, 79.86, 6.901, 79.861, 'tuk');
    final detour = fixture(
      restricted: true,
    ).route(6.9, 79.86, 6.901, 79.861, 'tuk');
    expect(short['meters'], closeTo(222, .1));
    expect(detour['meters'], closeTo(400, .1));
    expect(detour['instructions'], isNotEmpty);
  });
  test('only-turn restrictions and same-way U-turn handling', () {
    final graph = fixture(restricted: true, only: true);
    expect(graph.canTurn(0, 1, 2), false);
    expect(graph.canTurn(0, 1, 3), true);
    final blocked = fixture(restricted: true);
    expect(blocked.canTurn(0, 1, 3), false);
  });
  test('profile excludes car-only road and unsupported destinations', () {
    final graph = fixture(oneWay: true);
    graph.roads[0][3] = 1;
    expect(
      () => graph.route(6.9, 79.86, 6.9, 79.861, 'tuk'),
      throwsFormatException,
    );
    expect(() => graph.snap(51, 0, 'car'), throwsFormatException);
  });
  test('same-way U-turn prohibition allows continuing along that way', () {
    final graph = fixture(uTurn: true);
    graph.roadIds[3] = 0;
    expect(graph.canTurn(0, 1, 2), false);
    expect(graph.canTurn(0, 1, 3), true);
  });
  test(
    'offline search handles English and Sinhala; viewport returns roads',
    () {
      final graph = fixture();
      expect(graph.search('colom').single[0], 'Colombo');
      expect(graph.search('කොළ').single[0], 'Colombo');
      expect(graph.viewport(6.89, 79.85, 6.91, 79.87, 15)['lines'], isNotEmpty);
      expect(graph.viewport(-90, -180, 90, 180, 6)['lines'], isNotNull);
    },
  );
  test(
    'route progress measures deviation from road without adding fare distance',
    () {
      final route = fixture(oneWay: true).route(6.9, 79.86, 6.9, 79.861, 'car');
      final onRoad = RouteProgress.locate(route, const LatLng(6.9, 79.8605));
      final offRoad = RouteProgress.locate(route, const LatLng(6.901, 79.8605));
      expect(onRoad.alongMeters, closeTo(55.5, .1));
      expect(onRoad.distanceFromRoad, lessThan(1));
      expect(offRoad.distanceFromRoad, greaterThan(50));
    },
  );
  test(
    'bundled country graph supports real Sri Lanka journeys',
    () {
      final graph = NavigationGraph(
        Uint8List.fromList(
          gzip.decode(File('assets/sri_lanka.nav.gz').readAsBytesSync()),
        ),
      );
      expect(graph.nodeCount, greaterThan(100000));
      expect(graph.search('Kandy'), isNotEmpty);
      final overview = graph.viewport(5.7, 79.3, 10.1, 82.2, 7);
      expect(overview['lines'], isNotEmpty);
      for (final target in [
        (6.9271, 79.8612, 6.9147, 79.8730),
        (6.9271, 79.8612, 7.2906, 80.6337),
        (7.2906, 80.6337, 9.6615, 80.0255),
      ]) {
        final watch = Stopwatch()..start();
        final route = graph.route(
          target.$1,
          target.$2,
          target.$3,
          target.$4,
          'tuk',
        );
        expect(route['meters'], greaterThan(100));
        expect(route['points'], isNotEmpty);
        // Useful performance evidence for the actual shipped country graph.
        // ignore: avoid_print
        print(
          'Sri Lanka route ${(route['meters'] as num) / 1000} km, ${watch.elapsedMilliseconds} ms, ${route['expanded']} states',
        );
      }
      final carRoute = graph.route(6.9271, 79.8612, 7.2906, 80.6337, 'car');
      expect(carRoute['profile'], 'car');
      expect(carRoute['meters'], greaterThan(100000));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'bundled worker loads package asset and survives an invalid route',
    () async {
      final service = OfflineNavigationService.instance;
      try {
        final found = await service.request('search', {'query': 'Kandy'});
        expect(found['places'], isNotEmpty);
        await expectLater(
          service.request('route', {
            'startLat': 0,
            'startLon': 0,
            'endLat': 7.29,
            'endLon': 80.63,
            'profile': 'tuk',
          }),
          throwsFormatException,
        );
        final route = await service.request('route', {
          'startLat': 6.9271,
          'startLon': 79.8612,
          'endLat': 6.9147,
          'endLon': 79.8730,
          'profile': 'tuk',
        });
        expect(route['meters'], greaterThan(1000));
        final view = await service.request('viewport', {
          'south': 6.90,
          'west': 79.85,
          'north': 6.94,
          'east': 79.89,
          'zoom': 15,
        });
        expect(view['lines'], isNotEmpty);
      } finally {
        service.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

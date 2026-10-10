import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Compact CSR graph. No network, platform channel or UI work occurs here.
class NavigationGraph {
  NavigationGraph(Uint8List bytes) {
    final header = ByteData.sublistView(bytes);
    if (bytes.length < 24 ||
        ascii.decode(bytes.sublist(0, 7)) != 'RDXNAV1' ||
        header.getUint32(20, Endian.little) != 1) {
      throw const FormatException('Unsupported offline navigation map.');
    }
    nodeCount = header.getUint32(8, Endian.little);
    edgeCount = header.getUint32(12, Endian.little);
    final metadataLength = header.getUint32(16, Endian.little);
    var offset = 24 + metadataLength;
    final expected =
        offset + nodeCount * 8 + (nodeCount + 1) * 4 + edgeCount * 12;
    if (expected != bytes.length || metadataLength % 4 != 0 || nodeCount == 0) {
      throw const FormatException('Incomplete offline navigation map.');
    }
    metadata = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes.sublist(24, offset))) as Map,
    );
    coordinates = Int32List.view(
      bytes.buffer,
      bytes.offsetInBytes + offset,
      nodeCount * 2,
    );
    offset += nodeCount * 8;
    starts = Uint32List.view(
      bytes.buffer,
      bytes.offsetInBytes + offset,
      nodeCount + 1,
    );
    offset += (nodeCount + 1) * 4;
    targets = Uint32List.view(
      bytes.buffer,
      bytes.offsetInBytes + offset,
      edgeCount,
    );
    offset += edgeCount * 4;
    lengths = Uint32List.view(
      bytes.buffer,
      bytes.offsetInBytes + offset,
      edgeCount,
    );
    offset += edgeCount * 4;
    roadIds = Uint32List.view(
      bytes.buffer,
      bytes.offsetInBytes + offset,
      edgeCount,
    );
    roads = (metadata['roads'] as List).cast<List>();
    for (final raw in metadata['cells'] as List) {
      final cell = (raw as List).cast<int>();
      _cells['${cell[0]}:${cell[1]}'] = (cell[2], cell[3]);
    }
    for (final raw in metadata['restrictions'] as List? ?? []) {
      final r = raw as List;
      (_turns['${r[0]}:${r[1]}'] ??= []).add(r);
    }
    for (final raw in metadata['excludedComplexTurns'] as List? ?? []) {
      final r = raw as List;
      for (final from in r[0] as List) {
        (_complex[from as int] ??= {}).addAll((r[1] as List).cast<int>());
      }
    }
  }

  late final int nodeCount, edgeCount;
  late final Map<String, dynamic> metadata;
  late final Int32List coordinates;
  late final Uint32List starts, targets, lengths, roadIds;
  late final List<List> roads;
  final _cells = <String, (int, int)>{};
  final _turns = <String, List<List>>{};
  final _complex = <int, Set<int>>{};

  double lat(int node) => coordinates[node * 2] / 1e6;
  double lon(int node) => coordinates[node * 2 + 1] / 1e6;
  int _mask(String profile) => profile == 'car' ? 1 : 2;
  bool allowed(int edge, String profile) =>
      (roads[roadIds[edge]][3] as int) & _mask(profile) != 0;
  double seconds(int edge, double meters) =>
      meters * 3.6 / (roads[roadIds[edge]][2] as num);

  Iterable<int> _nodes(
    double south,
    double west,
    double north,
    double east,
  ) sync* {
    final cellSize = (metadata['cellE6'] as num).toDouble() / 1e6;
    for (
      var y = (south / cellSize).floor();
      y <= (north / cellSize).floor();
      y++
    ) {
      for (
        var x = (west / cellSize).floor();
        x <= (east / cellSize).floor();
        x++
      ) {
        final range = _cells['$y:$x'];
        if (range == null) continue;
        for (var node = range.$1; node < range.$2; node++) {
          yield node;
        }
      }
    }
  }

  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const rad = math.pi / 180;
    final a =
        math.pow(math.sin((lat2 - lat1) * rad / 2), 2) +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.pow(math.sin((lon2 - lon1) * rad / 2), 2);
    return 12742000 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  static ({double lat, double lon, double t, double meters}) project(
    double latitude,
    double longitude,
    double aLat,
    double aLon,
    double bLat,
    double bLon,
  ) {
    final scale = math.cos(latitude * math.pi / 180);
    final dx = (bLon - aLon) * scale, dy = bLat - aLat;
    final squared = dx * dx + dy * dy;
    final t = squared == 0
        ? 0.0
        : (((longitude - aLon) * scale * dx + (latitude - aLat) * dy) / squared)
              .clamp(0.0, 1.0);
    final latitudeOnRoad = aLat + dy * t,
        longitudeOnRoad = aLon + (bLon - aLon) * t;
    return (
      lat: latitudeOnRoad,
      lon: longitudeOnRoad,
      t: t,
      meters: distance(latitude, longitude, latitudeOnRoad, longitudeOnRoad),
    );
  }

  Map<String, dynamic> snap(double latitude, double longitude, String profile) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < 5.7 ||
        latitude > 10.1 ||
        longitude < 79.3 ||
        longitude > 82.2) {
      throw const FormatException(
        'Choose a destination inside the bundled Sri Lanka map.',
      );
    }
    int? bestEdge, bestSource;
    var best = double.infinity;
    double bestT = 0, bestLat = 0, bestLon = 0;
    // Road geometry nodes are usually close together; wider cells include long straight segments.
    for (final node in _nodes(
      latitude - .035,
      longitude - .035,
      latitude + .035,
      longitude + .035,
    )) {
      for (var edge = starts[node]; edge < starts[node + 1]; edge++) {
        if (!allowed(edge, profile)) continue;
        final target = targets[edge];
        final p = project(
          latitude,
          longitude,
          lat(node),
          lon(node),
          lat(target),
          lon(target),
        );
        if (p.meters < best) {
          best = p.meters;
          bestEdge = edge;
          bestSource = node;
          bestT = p.t;
          bestLat = p.lat;
          bestLon = p.lon;
        }
      }
    }
    if (bestEdge == null || best > 300) {
      throw const FormatException(
        'No accessible mapped motor road within 300 m. Pick a point closer to a public road.',
      );
    }
    final directions = <Map<String, dynamic>>[
      {'edge': bestEdge, 'source': bestSource, 't': bestT},
    ];
    final target = targets[bestEdge];
    for (var edge = starts[target]; edge < starts[target + 1]; edge++) {
      if (targets[edge] == bestSource &&
          roadIds[edge] == roadIds[bestEdge] &&
          allowed(edge, profile)) {
        directions.add({'edge': edge, 'source': target, 't': 1 - bestT});
      }
    }
    return {
      'lat': bestLat,
      'lon': bestLon,
      'offsetMeters': best,
      'directions': directions,
    };
  }

  bool canTurn(int incoming, int node, int outgoing) {
    final from = roadIds[incoming], to = roadIds[outgoing];
    if (_complex[from]?.contains(to) == true) return false;
    final rules = _turns['$node:$from'];
    if (rules == null) return true;
    for (final r in rules) {
      final kind = r[3] as String;
      final matches = (r[2] as List).contains(to);
      // Same-way U-turns must not accidentally forbid continuing on that road.
      var reverse = true;
      if (kind.endsWith('u_turn') && matches && from == to) {
        final previous = sourceOf(incoming);
        reverse = targets[outgoing] == previous;
      }
      if (kind.startsWith('only_') &&
          (!matches || (kind.endsWith('u_turn') && !reverse)))
        return false;
      if (kind.startsWith('no_') &&
          matches &&
          (!kind.endsWith('u_turn') || reverse))
        return false;
    }
    return true;
  }

  int sourceOf(int edge) {
    var low = 0, high = nodeCount;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (starts[mid] <= edge) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  Map<String, dynamic> route(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
    String profile,
  ) {
    final start = snap(startLat, startLon, profile),
        end = snap(endLat, endLon, profile);
    final destination = <int, double>{
      for (final direction in end['directions'] as List)
        direction['edge'] as int: (direction['t'] as num).toDouble(),
    };
    final distances = Float64List(edgeCount);
    final parents = Int32List(edgeCount);
    final seen = Uint8List(edgeCount);
    final heap = _Heap();
    final roots = <int, double>{};
    double bestSeconds = double.infinity;
    int? finalState, finalEdge;
    double finalFraction = 0;
    List<int>? directEdges;
    double directMeters = 0;
    for (final direction in start['directions'] as List) {
      final edge = direction['edge'] as int;
      final t = (direction['t'] as num).toDouble();
      final endT = destination[edge];
      if (endT != null && endT >= t) {
        final length = lengths[edge] / 100 * (endT - t);
        final cost = seconds(edge, length);
        if (cost < bestSeconds) {
          bestSeconds = cost;
          directEdges = [edge];
          directMeters = length;
        }
      }
      final cost = seconds(edge, lengths[edge] / 100 * (1 - t));
      seen[edge] = 1;
      distances[edge] = cost;
      parents[edge] = -1;
      roots[edge] = t;
      heap.add(edge, cost + _heuristic(targets[edge], end, profile));
    }
    var expanded = 0;
    while (heap.isNotEmpty) {
      final (incoming, priority) = heap.remove();
      if (priority >= bestSeconds) break;
      if (seen[incoming] == 2) continue;
      seen[incoming] = 2;
      expanded++;
      final node = targets[incoming];
      for (var edge = starts[node]; edge < starts[node + 1]; edge++) {
        if (!allowed(edge, profile) || !canTurn(incoming, node, edge)) continue;
        final endT = destination[edge];
        if (endT != null) {
          final cost =
              distances[incoming] + seconds(edge, lengths[edge] / 100 * endT);
          if (cost < bestSeconds) {
            bestSeconds = cost;
            finalState = incoming;
            finalEdge = edge;
            finalFraction = endT;
            directEdges = null;
          }
        }
        final cost = distances[incoming] + seconds(edge, lengths[edge] / 100);
        if (seen[edge] == 0 || cost < distances[edge]) {
          distances[edge] = cost;
          parents[edge] = incoming;
          seen[edge] = 1;
          heap.add(edge, cost + _heuristic(targets[edge], end, profile));
        }
      }
    }
    if (!bestSeconds.isFinite)
      throw const FormatException(
        'No connected public-road route found for this vehicle. Try a different road or destination.',
      );
    final edges = <int>[];
    final segmentMeters = <double>[];
    if (directEdges != null) {
      edges.addAll(directEdges);
      segmentMeters.add(directMeters);
    } else {
      var state = finalState!;
      while (true) {
        edges.add(state);
        if (parents[state] == -1) break;
        state = parents[state];
      }
      final ordered = edges.reversed.toList();
      edges
        ..clear()
        ..addAll(ordered);
      for (var i = 0; i < edges.length; i++) {
        segmentMeters.add(
          lengths[edges[i]] / 100 * (i == 0 ? 1 - roots[edges[i]]! : 1),
        );
      }
      edges.add(finalEdge!);
      segmentMeters.add(lengths[finalEdge] / 100 * finalFraction);
    }
    final points = <List<double>>[
      [start['lat'] as double, start['lon'] as double],
    ];
    final cumulative = <double>[0];
    var totalMeters = 0.0;
    for (var i = 0; i < edges.length; i++) {
      totalMeters += segmentMeters[i];
      cumulative.add(totalMeters);
      if (i == edges.length - 1) {
        points.add([end['lat'] as double, end['lon'] as double]);
      } else {
        points.add([lat(targets[edges[i]]), lon(targets[edges[i]])]);
      }
    }
    return {
      'points': points,
      'meters': totalMeters,
      'seconds': bestSeconds,
      'cumulative': cumulative,
      'instructions': _instructions(edges, points, cumulative),
      'startOffsetMeters': start['offsetMeters'],
      'endOffsetMeters': end['offsetMeters'],
      'expanded': expanded,
      'profile': profile,
    };
  }

  double _heuristic(int node, Map<String, dynamic> end, String profile) =>
      distance(
        lat(node),
        lon(node),
        end['lat'] as double,
        end['lon'] as double,
      ) *
      .999 *
      3.6 /
      (profile == 'car' ? 80 : 60);

  List<Map<String, dynamic>> _instructions(
    List<int> edges,
    List<List<double>> points,
    List<double> cumulative,
  ) {
    final instructions = <Map<String, dynamic>>[];
    String name(int edge) => (roads[roadIds[edge]][0] as String).isEmpty
        ? 'the road'
        : roads[roadIds[edge]][0] as String;
    instructions.add({
      'atMeters': 0.0,
      'pointIndex': 0,
      'text': 'Head along ${name(edges.first)}',
      'kind': 'depart',
    });
    for (var i = 1; i < edges.length; i++) {
      if (cumulative[i + 1] - cumulative[i] < .5 || cumulative[i] < .5)
        continue;
      final previous = roads[roadIds[edges[i - 1]]],
          next = roads[roadIds[edges[i]]];
      final roundBefore = (previous[3] as int) & 4 != 0,
          roundAfter = (next[3] as int) & 4 != 0;
      final before = bearing(
        points[i - 1][0],
        points[i - 1][1],
        points[i][0],
        points[i][1],
      );
      final after = bearing(
        points[i][0],
        points[i][1],
        points[i + 1][0],
        points[i + 1][1],
      );
      final angle = (after - before + 540) % 360 - 180;
      if (!roundBefore && roundAfter) {
        instructions.add({
          'atMeters': cumulative[i],
          'pointIndex': i,
          'text': 'Enter the roundabout',
          'kind': 'roundabout',
        });
      } else if (roundBefore && !roundAfter) {
        instructions.add({
          'atMeters': cumulative[i],
          'pointIndex': i,
          'text': 'Exit the roundabout onto ${name(edges[i])}',
          'kind': 'exit',
        });
      } else if (!roundAfter &&
          (roadIds[edges[i - 1]] != roadIds[edges[i]]) &&
          (previous[0] != next[0] || angle.abs() > 40)) {
        final kind = angle.abs() > 150
            ? 'u_turn'
            : angle.abs() < 25
            ? 'straight'
            : angle > 0
            ? 'right'
            : 'left';
        final text = kind == 'u_turn'
            ? 'Make a U-turn onto ${name(edges[i])}'
            : kind == 'straight'
            ? 'Continue onto ${name(edges[i])}'
            : 'Turn $kind onto ${name(edges[i])}';
        instructions.add({
          'atMeters': cumulative[i],
          'pointIndex': i,
          'text': text,
          'kind': kind,
        });
      }
    }
    instructions.add({
      'atMeters': cumulative.last,
      'pointIndex': points.length - 1,
      'text': 'Arrive at your destination',
      'kind': 'arrive',
    });
    return instructions;
  }

  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    const rad = math.pi / 180;
    final delta = (lon2 - lon1) * rad;
    return (math.atan2(
                  math.sin(delta) * math.cos(lat2 * rad),
                  math.cos(lat1 * rad) * math.sin(lat2 * rad) -
                      math.sin(lat1 * rad) *
                          math.cos(lat2 * rad) *
                          math.cos(delta),
                ) /
                rad +
            360) %
        360;
  }

  Map<String, dynamic> viewport(
    double south,
    double west,
    double north,
    double east,
    double zoom,
  ) {
    south = south.clamp(5.7, 10.1);
    north = north.clamp(5.7, 10.1);
    west = west.clamp(79.3, 82.2);
    east = east.clamp(79.3, 82.2);
    final lines = <List<num>>[];
    final labels = <List<dynamic>>[];
    final labelled = <String>{};
    final maxClass = zoom < 9
        ? 1
        : zoom < 11
        ? 2
        : zoom < 13
        ? 4
        : 9;
    final overview = metadata['overviewRoads'] as List?;
    if (zoom < 11 && overview != null) {
      for (final road in overview) {
        if ((road[0] as int) > maxClass) continue;
        final geometry = road[1] as List;
        for (var i = 1; i < geometry.length; i++) {
          final a = geometry[i - 1] as List, b = geometry[i] as List;
          final aLat = (a[0] as num) / 1e6, aLon = (a[1] as num) / 1e6;
          final bLat = (b[0] as num) / 1e6, bLon = (b[1] as num) / 1e6;
          if (math.max(aLat, bLat) < south ||
              math.min(aLat, bLat) > north ||
              math.max(aLon, bLon) < west ||
              math.min(aLon, bLon) > east)
            continue;
          lines.add([aLat, aLon, bLat, bLon, road[0] as int]);
        }
      }
    }
    for (final node
        in (zoom < 11 && overview != null)
            ? const Iterable<int>.empty()
            : _nodes(south - .04, west - .04, north + .04, east + .04)) {
      for (var edge = starts[node]; edge < starts[node + 1]; edge++) {
        final target = targets[edge], road = roads[roadIds[edge]];
        if ((road[1] as int) > maxClass) continue;
        // Render both directions once. One-way edges retain their geometry.
        if (target < node) {
          var reverse = false;
          for (
            var other = starts[target];
            other < starts[target + 1];
            other++
          ) {
            if (targets[other] == node && roadIds[other] == roadIds[edge]) {
              reverse = true;
              break;
            }
          }
          if (reverse) continue;
        }
        if (math.max(lat(node), lat(target)) < south ||
            math.min(lat(node), lat(target)) > north ||
            math.max(lon(node), lon(target)) < west ||
            math.min(lon(node), lon(target)) > east)
          continue;
        lines.add([
          lat(node),
          lon(node),
          lat(target),
          lon(target),
          road[1] as int,
        ]);
        final name = road[0] as String;
        if (zoom >= 14 &&
            name.isNotEmpty &&
            labelled.add(name) &&
            labels.length < 45) {
          labels.add([name, lat(node), lon(node)]);
        }
        if (lines.length >= 25000) break;
      }
      if (lines.length >= 25000) break;
    }
    final places = (metadata['places'] as List)
        .where(
          (p) =>
              p[1] / 1e6 >= south &&
              p[1] / 1e6 <= north &&
              p[2] / 1e6 >= west &&
              p[2] / 1e6 <= east &&
              (zoom >= 13 || ['city', 'town'].contains(p[3])),
        )
        .take(35)
        .toList();
    return {'lines': lines, 'labels': labels, 'places': places};
  }

  List<List> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final places = (metadata['places'] as List)
        .cast<List>()
        .where(
          (p) =>
              (p[0] as String).toLowerCase().contains(q) ||
              (p[4] as String).toLowerCase().contains(q),
        )
        .toList();
    places.sort((a, b) {
      final aPrefix = (a[0] as String).toLowerCase().startsWith(q),
          bPrefix = (b[0] as String).toLowerCase().startsWith(q);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return (a[0] as String).compareTo(b[0] as String);
    });
    return places.take(30).toList();
  }
}

class _Heap {
  final _states = <int>[];
  final _priorities = <double>[];
  bool get isNotEmpty => _states.isNotEmpty;
  void add(int state, double priority) {
    var index = _states.length;
    _states.add(state);
    _priorities.add(priority);
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (_priorities[parent] <= priority) break;
      _states[index] = _states[parent];
      _priorities[index] = _priorities[parent];
      index = parent;
    }
    _states[index] = state;
    _priorities[index] = priority;
  }

  (int, double) remove() {
    final result = (_states.first, _priorities.first);
    final state = _states.removeLast(), priority = _priorities.removeLast();
    if (_states.isEmpty) return result;
    var index = 0;
    while (index * 2 + 1 < _states.length) {
      var child = index * 2 + 1;
      if (child + 1 < _states.length &&
          _priorities[child + 1] < _priorities[child])
        child++;
      if (_priorities[child] >= priority) break;
      _states[index] = _states[child];
      _priorities[index] = _priorities[child];
      index = child;
    }
    _states[index] = state;
    _priorities[index] = priority;
    return result;
  }
}

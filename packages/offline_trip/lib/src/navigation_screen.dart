import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_graph.dart';
import 'navigation_service.dart';

class OfflineDestination {
  const OfflineDestination(
    this.latitude,
    this.longitude,
    this.name, {
    this.profile = 'tuk',
  });
  final double latitude, longitude;
  final String name, profile;
  LatLng get point => LatLng(latitude, longitude);
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
  };
  static OfflineDestination? fromJson(dynamic value, {String profile = 'tuk'}) {
    if (value is! Map ||
        value['latitude'] is! num ||
        value['longitude'] is! num)
      return null;
    final lat = (value['latitude'] as num).toDouble(),
        lon = (value['longitude'] as num).toDouble();
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 5.7 ||
        lat > 10.1 ||
        lon < 79.3 ||
        lon > 82.2)
      return null;
    return OfflineDestination(
      lat,
      lon,
      value['name']?.toString() ?? 'Map pin',
      profile: profile,
    );
  }
}

/// Country road map rendered exclusively from the application asset.
class BundledRoadMap extends StatefulWidget {
  const BundledRoadMap({
    super.key,
    this.initialCenter = const LatLng(7.8, 80.7),
    this.initialZoom = 7,
    this.route = const [],
    this.trail = const [],
    this.destination,
    this.position,
    this.controller,
    this.onLongPress,
    this.onUserMove,
  });
  final LatLng initialCenter;
  final double initialZoom;
  final List<LatLng> route, trail;
  final LatLng? destination, position;
  final MapController? controller;
  final void Function(LatLng)? onLongPress;
  final VoidCallback? onUserMove;
  @override
  State<BundledRoadMap> createState() => _BundledRoadMapState();
}

class _BundledRoadMapState extends State<BundledRoadMap> {
  late final MapController _map = widget.controller ?? MapController();
  Timer? _debounce;
  int _request = 0;
  Map<String, dynamic>? _view;
  String? _error;
  bool _loading = true;
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _render);
  }

  Future<void> _render() async {
    final serial = ++_request;
    final camera = _map.camera, bounds = _map.camera.visibleBounds;
    try {
      final view = await OfflineNavigationService.instance.request('viewport', {
        'south': bounds.south,
        'west': bounds.west,
        'north': bounds.north,
        'east': bounds.east,
        'zoom': camera.zoom,
      });
      if (mounted && serial == _request)
        setState(() {
          _view = view;
          _loading = false;
          _error = null;
        });
    } catch (error) {
      if (mounted && serial == _request)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = (_view?['lines'] as List? ?? []).cast<List>();
    final places = (_view?['places'] as List? ?? []).cast<List>();
    final labels = (_view?['labels'] as List? ?? []).cast<List>();
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 6,
            maxZoom: 18,
            backgroundColor: const Color(0xffedf1e7),
            onMapReady: _schedule,
            onPositionChanged: (_, hasGesture) {
              _schedule();
              if (hasGesture) widget.onUserMove?.call();
            },
            onLongPress: (_, point) => widget.onLongPress?.call(point),
          ),
          children: [
            PolylineLayer(
              polylines: [
                for (final line in lines)
                  Polyline(
                    points: [
                      LatLng(
                        (line[0] as num).toDouble(),
                        (line[1] as num).toDouble(),
                      ),
                      LatLng(
                        (line[2] as num).toDouble(),
                        (line[3] as num).toDouble(),
                      ),
                    ],
                    color: (line[4] as int) <= 2
                        ? const Color(0xffd69d52)
                        : Colors.white,
                    strokeWidth: (line[4] as int) <= 2 ? 3.5 : 2,
                    borderColor: const Color(0xffb7b9ad),
                    borderStrokeWidth: .5,
                  ),
                if (widget.trail.length > 1)
                  Polyline(
                    points: widget.trail,
                    color: Colors.deepOrange,
                    strokeWidth: 3,
                  ),
                if (widget.route.length > 1)
                  Polyline(
                    points: widget.route,
                    color: Colors.blue.shade700,
                    strokeWidth: 5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final place in places)
                  Marker(
                    point: LatLng(
                      (place[1] as num) / 1e6,
                      (place[2] as num) / 1e6,
                    ),
                    width: 145,
                    height: 26,
                    child: Text(
                      place[0].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                for (final label in labels)
                  Marker(
                    point: LatLng(
                      (label[1] as num).toDouble(),
                      (label[2] as num).toDouble(),
                    ),
                    width: 130,
                    height: 22,
                    child: Text(
                      label[0].toString(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                if (widget.destination != null)
                  Marker(
                    point: widget.destination!,
                    width: 40,
                    height: 45,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                if (widget.position != null)
                  Marker(
                    point: widget.position!,
                    width: 32,
                    height: 32,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 3,
          right: 4,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Offline map data'),
                content: const SingleChildScrollView(
                  child: SelectableText(
                    '© OpenStreetMap contributors\n\nSri Lanka road database, licensed under ODbL 1.0.\n\n'
                    'Copyright: https://www.openstreetmap.org/copyright\n\n'
                    'License: https://opendatacommons.org/licenses/odbl/1-0/\n\n'
                    'Source: https://download.geofabrik.de/asia/sri-lanka.html',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const ColoredBox(
              color: Colors.white70,
              child: Padding(
                padding: EdgeInsets.all(3),
                child: Text(
                  '© OpenStreetMap contributors · ODbL',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _render,
                      child: const Text('Retry map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OfflineNavigationScreen extends StatefulWidget {
  const OfflineNavigationScreen({
    super.key,
    this.initialPosition,
    this.destination,
    this.selectDestination = false,
    this.profile = 'tuk',
  });
  final LatLng? initialPosition;
  final OfflineDestination? destination;
  final bool selectDestination;
  final String profile;
  @override
  State<OfflineNavigationScreen> createState() =>
      _OfflineNavigationScreenState();
}

class _OfflineNavigationScreenState extends State<OfflineNavigationScreen>
    with WidgetsBindingObserver {
  final _map = MapController();
  final _search = TextEditingController();
  StreamSubscription<Position>? _positions;
  Timer? _searchDelay;
  List<List> _matches = [];
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _route;
  LatLng? _position;
  OfflineDestination? _destination;
  late String _profile;
  String? _error;
  bool _routing = false, _following = false, _selectStart = false;
  int _searchSequence = 0, _routeSequence = 0, _offRouteFixes = 0;
  double _progress = 0;
  DateTime? _lastReroute;
  DateTime? _lastRouteAttempt;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _position = widget.initialPosition;
    _destination = widget.destination;
    _profile = widget.profile;
    if (!widget.selectDestination) _gps();
    if (!widget.selectDestination &&
        _position != null &&
        _destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _calculate();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.selectDestination) {
      _gps();
    } else if (state != AppLifecycleState.resumed) {
      _positions?.cancel();
      _positions = null;
    }
  }

  Future<void> _gps() async {
    try {
      await _positions?.cancel();
      _positions = null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const FormatException(
          'Allow location access for GPS navigation, or choose a start pin.',
        );
      }
      if (!await Geolocator.isLocationServiceEnabled())
        throw const FormatException(
          'Turn on location services for GPS navigation.',
        );
      if (!mounted) return;
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (Object error) {
              if (mounted) setState(() => _error = error.toString());
            },
          );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _onPosition(Position fix) {
    if (!mounted || fix.isMocked || !fix.accuracy.isFinite || fix.accuracy > 30)
      return;
    final point = LatLng(fix.latitude, fix.longitude);
    setState(() {
      _position = point;
      _selectStart = false;
    });
    if (_following)
      _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
    if (_destination == null) return;
    if (_route == null) {
      if (!_routing &&
          (_lastRouteAttempt == null ||
              DateTime.now().difference(_lastRouteAttempt!).inSeconds >= 10))
        _calculate();
      return;
    }
    final progress = RouteProgress.locate(_route!, point);
    setState(() => _progress = progress.alongMeters);
    if (progress.distanceFromRoad > 50) {
      _offRouteFixes++;
    } else {
      _offRouteFixes = 0;
    }
    if (_offRouteFixes >= 2 &&
        !_routing &&
        (_lastReroute == null ||
            DateTime.now().difference(_lastReroute!).inSeconds >= 10)) {
      _lastReroute = DateTime.now();
      _offRouteFixes = 0;
      _calculate();
    }
  }

  Future<void> _calculate() async {
    if (_position == null || _destination == null) return;
    final serial = ++_routeSequence;
    final start = _position!, destination = _destination!;
    _lastRouteAttempt = DateTime.now();
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final route = await OfflineNavigationService.instance.request('route', {
        'startLat': start.latitude,
        'startLon': start.longitude,
        'endLat': destination.latitude,
        'endLon': destination.longitude,
        'profile': _profile,
      });
      if (!mounted || serial != _routeSequence) return;
      setState(() {
        _route = route;
        _progress = 0;
        _routePoints = (route['points'] as List)
            .map(
              (p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            )
            .toList();
      });
      if (!_following)
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(45),
          ),
        );
    } catch (error) {
      if (mounted && serial == _routeSequence)
        setState(() {
          _error = error.toString();
          _route = null;
          _routePoints = [];
        });
    } finally {
      if (mounted && serial == _routeSequence) setState(() => _routing = false);
    }
  }

  void _choose(LatLng point, String name) {
    if (point.latitude < 5.7 ||
        point.latitude > 10.1 ||
        point.longitude < 79.3 ||
        point.longitude > 82.2) {
      setState(() => _error = 'Choose a point inside Sri Lanka.');
      return;
    }
    ++_routeSequence;
    setState(() {
      _matches = [];
      _route = null;
      _routePoints = [];
      _routing = false;
      _progress = 0;
      _error = null;
      if (_selectStart) {
        _position = point;
        _selectStart = false;
      } else {
        _destination = OfflineDestination(
          point.latitude,
          point.longitude,
          name,
          profile: _profile,
        );
      }
    });
    _map.move(point, 14);
    if (!widget.selectDestination) _calculate();
  }

  void _find(String query) {
    final serial = ++_searchSequence;
    _searchDelay?.cancel();
    if (query.trim().length < 2) {
      setState(() => _matches = []);
      return;
    }
    _searchDelay = Timer(const Duration(milliseconds: 250), () async {
      try {
        final found = await OfflineNavigationService.instance.request(
          'search',
          {'query': query},
        );
        if (mounted && serial == _searchSequence)
          setState(() => _matches = (found['places'] as List).cast<List>());
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positions?.cancel();
    _searchDelay?.cancel();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  static String _distance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
  @override
  Widget build(BuildContext context) {
    final instructions = (_route?['instructions'] as List? ?? []).cast<Map>();
    final total = (_route?['meters'] as num?)?.toDouble() ?? 0;
    final remaining = (total - _progress).clamp(0.0, double.infinity);
    Map? next;
    for (final instruction in instructions) {
      if ((instruction['atMeters'] as num) >= _progress + 10) {
        next = instruction;
        break;
      }
    }
    final arrived =
        _destination != null &&
        _position != null &&
        NavigationGraph.distance(
              _position!.latitude,
              _position!.longitude,
              _destination!.latitude,
              _destination!.longitude,
            ) <
            25;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectDestination
              ? 'Choose offline destination'
              : 'Offline navigation',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: _find,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search Sri Lankan towns and villages',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_matches.isNotEmpty)
            SizedBox(
              height: 155,
              child: ListView(
                children: [
                  for (final place in _matches)
                    ListTile(
                      dense: true,
                      title: Text(place[0].toString()),
                      subtitle: Text(place[3].toString()),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _choose(
                          LatLng(
                            (place[1] as num) / 1e6,
                            (place[2] as num) / 1e6,
                          ),
                          place[0].toString(),
                        );
                      },
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectStart
                        ? 'Long-press to choose a start point'
                        : 'Long-press the map to choose a destination',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DropdownButton<String>(
                  value: _profile,
                  items: const [
                    DropdownMenuItem(
                      value: 'tuk',
                      child: Text('Three-wheeler'),
                    ),
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ++_routeSequence;
                    setState(() {
                      _profile = value;
                      _route = null;
                      _routePoints = [];
                      _routing = false;
                    });
                    if (!widget.selectDestination) _calculate();
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_routing) const LinearProgressIndicator(),
          Expanded(
            child: BundledRoadMap(
              controller: _map,
              initialCenter:
                  _position ?? _destination?.point ?? const LatLng(7.8, 80.7),
              initialZoom: _position == null && _destination == null ? 7 : 14,
              position: _position,
              destination: _destination?.point,
              route: _routePoints,
              onLongPress: (point) => _choose(point, 'Map pin'),
              onUserMove: () {
                if (_following) setState(() => _following = false);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_destination != null)
                    Text(
                      _destination!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (_route != null) ...[
                    Text(
                      arrived
                          ? 'You have arrived'
                          : '${_distance(remaining)} remaining · ~${(((_route!['seconds'] as num) * (total == 0 ? 0 : remaining / total)) / 60).ceil()} min',
                    ),
                    if (next != null && !arrived)
                      Text(
                        '${_distance(((next['atMeters'] as num) - _progress).clamp(0, double.infinity).toDouble())} · ${next['text']}',
                      ),
                    if ((_route!['endOffsetMeters'] as num) > 25)
                      Text(
                        'Destination is ${_distance((_route!['endOffsetMeters'] as num).toDouble())} from the routed road.',
                      ),
                  ],
                  if (widget.selectDestination)
                    FilledButton.icon(
                      onPressed: _destination == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              OfflineDestination(
                                _destination!.latitude,
                                _destination!.longitude,
                                _destination!.name,
                                profile: _profile,
                              ),
                            ),
                      icon: const Icon(Icons.check),
                      label: const Text('Use this destination'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _following = true);
                            if (_position != null) _map.move(_position!, 16);
                            _gps();
                            _calculate();
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text('Follow GPS'),
                        ),
                        TextButton(
                          onPressed: () {
                            _positions?.cancel();
                            _positions = null;
                            setState(() {
                              _following = false;
                              _selectStart = true;
                            });
                          },
                          child: const Text('Choose start pin'),
                        ),
                        if (_route != null)
                          TextButton(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => SafeArea(
                                child: ListView(
                                  children: [
                                    for (final instruction in instructions)
                                      ListTile(
                                        title: Text(
                                          instruction['text'].toString(),
                                        ),
                                        subtitle: Text(
                                          _distance(
                                            (instruction['atMeters'] as num)
                                                .toDouble(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            child: const Text('All directions'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteProgress {
  const RouteProgress(this.alongMeters, this.distanceFromRoad);
  final double alongMeters, distanceFromRoad;
  static RouteProgress locate(Map<String, dynamic> route, LatLng position) {
    final points = route['points'] as List,
        cumulative = route['cumulative'] as List;
    double closest = double.infinity, along = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i] as List, b = points[i + 1] as List;
      final projection = NavigationGraph.project(
        position.latitude,
        position.longitude,
        (a[0] as num).toDouble(),
        (a[1] as num).toDouble(),
        (b[0] as num).toDouble(),
        (b[1] as num).toDouble(),
      );
      if (projection.meters < closest) {
        closest = projection.meters;
        along =
            (cumulative[i] as num).toDouble() +
            projection.t *
                ((cumulative[i + 1] as num) - (cumulative[i] as num));
      }
    }
    return RouteProgress(along, closest);
  }
}

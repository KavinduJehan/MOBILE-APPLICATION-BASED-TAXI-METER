import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_graph.dart';
import 'navigation_service.dart';
import 'offline_widgets.dart';

class OfflineDestination {
  const OfflineDestination(
    this.latitude,
    this.longitude,
    this.name, {
    this.profile = 'car',
  });
  final double latitude, longitude;
  final String name, profile;
  LatLng get point => LatLng(latitude, longitude);
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'name': name,
  };
  static OfflineDestination? fromJson(dynamic value, {String profile = 'car'}) {
    if (value is! Map ||
        value['latitude'] is! num ||
        value['longitude'] is! num) {
      return null;
    }
    final lat = (value['latitude'] as num).toDouble(),
        lon = (value['longitude'] as num).toDouble();
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 5.7 ||
        lat > 10.1 ||
        lon < 79.3 ||
        lon > 82.2) {
      return null;
    }
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
    this.onLandmarkSelected,
    this.onLocate,
  });
  final LatLng initialCenter;
  final double initialZoom;
  final List<LatLng> route, trail;
  final LatLng? destination, position;
  final MapController? controller;
  final void Function(LatLng)? onLongPress;
  final VoidCallback? onUserMove;
  final void Function(OfflineDestination)? onLandmarkSelected;
  final VoidCallback? onLocate;
  static IconData landmarkIcon(String kind) => switch (kind) {
    'railway_station' => Icons.train,
    'bus_station' || 'bus_stop' => Icons.directions_bus,
    'fuel' => Icons.local_gas_station,
    'hospital' || 'clinic' => Icons.local_hospital,
    'pharmacy' => Icons.local_pharmacy,
    'airport' => Icons.flight,
    'police' => Icons.local_police,
    'bank' || 'atm' => Icons.account_balance,
    'restaurant' || 'cafe' => Icons.restaurant,
    'school' || 'university' => Icons.school,
    'hotel' => Icons.hotel,
    'supermarket' || 'mall' || 'convenience' => Icons.shopping_cart,
    'parking' => Icons.local_parking,
    'place_of_worship' => Icons.temple_buddhist,
    _ => Icons.place,
  };
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
  bool _previewFollowing = true;
  @override
  void didUpdateWidget(covariant BundledRoadMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        _previewFollowing &&
        widget.position != null &&
        widget.position != oldWidget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(widget.position!, 15);
      });
    }
  }

  Future<void> _locate() async {
    if (widget.onLocate != null) {
      widget.onLocate!();
      return;
    }
    try {
      LatLng? point = widget.position;
      if (point == null) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw const FormatException('Allow location access in app settings.');
        }
        final fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        point = LatLng(fix.latitude, fix.longitude);
      }
      if (mounted) {
        _previewFollowing = true;
        _map.move(point, 15);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check GPS and location permission, then try again.'),
          ),
        );
      }
    }
  }

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
      if (mounted && serial == _request) {
        setState(() {
          _view = view;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && serial == _request) {
        setState(() {
          _loading = false;
          _error = 'The offline map could not open. Tap Retry map.';
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.controller == null) _map.dispose();
    super.dispose();
  }

  Marker _landmarkMarker(List landmark) {
    final destination = OfflineDestination(
      (landmark[1] as num) / 1e6,
      (landmark[2] as num) / 1e6,
      landmark[0].toString(),
    );
    final kind = landmark[3] as String;
    return Marker(
      point: destination.point,
      width: 132,
      height: 52,
      child: GestureDetector(
        onTap: () => _showLandmark(destination, kind),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 3),
                ],
              ),
              child: Icon(
                BundledRoadMap.landmarkIcon(kind),
                size: 18,
                color: const Color(0xff405b88),
              ),
            ),
            Container(
              color: Colors.white.withValues(alpha: .9),
              child: Text(
                destination.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLandmark(OfflineDestination destination, String kind) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                BundledRoadMap.landmarkIcon(kind),
                size: 32,
                color: Colors.indigo,
              ),
              Text(
                destination.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(kind.replaceAll('_', ' '), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate here'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  if (widget.onLandmarkSelected != null) {
                    widget.onLandmarkSelected!(destination);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OfflineNavigationScreen(
                          initialPosition: widget.position,
                          destination: destination,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = (_view?['lines'] as List? ?? []).cast<List>();
    final places = (_view?['places'] as List? ?? []).cast<List>();
    final labels = (_view?['labels'] as List? ?? []).cast<List>();
    final landmarks = (_view?['landmarks'] as List? ?? []).cast<List>();
    List<LatLng> geometry(List points) => points
        .map((p) => LatLng((p[0] as num) / 1e6, (p[1] as num) / 1e6))
        .toList();
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 6,
            maxZoom: 18,
            backgroundColor: const Color(0xffc6e5f2),
            onMapReady: _schedule,
            onPositionChanged: (_, hasGesture) {
              _schedule();
              if (hasGesture) widget.onUserMove?.call();
              if (hasGesture) _previewFollowing = false;
            },
            onLongPress: (_, point) => widget.onLongPress?.call(point),
          ),
          children: [
            PolygonLayer(
              polygons: [
                for (final land in _view?['land'] as List? ?? [])
                  Polygon(
                    points: geometry(land as List),
                    color: const Color(0xfff6f3ed),
                    borderColor: const Color(0xff90bfd3),
                    borderStrokeWidth: 1,
                  ),
                for (final surface in _view?['surfaces'] as List? ?? [])
                  Polygon(
                    points: geometry(surface[1] as List),
                    color: surface[0] == 'water'
                        ? const Color(0xffb3dced)
                        : surface[0] == 'park'
                        ? const Color(0xffcee3c3)
                        : const Color(0xffdfd8ce),
                    borderColor: surface[0] == 'building'
                        ? const Color(0xffc5bbae)
                        : Colors.transparent,
                    borderStrokeWidth: .6,
                  ),
              ],
            ),
            PolylineLayer(
              polylines: [
                for (final railway in _view?['railways'] as List? ?? [])
                  Polyline(
                    points: geometry(railway as List),
                    color: const Color(0xff8c8391),
                    strokeWidth: 1.5,
                  ),
              ],
            ),
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
                for (final landmark in landmarks) _landmarkMarker(landmark),
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
        Positioned(
          right: 10,
          top: MediaQuery.paddingOf(context).top + 10,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Zoom in',
                onPressed: () => _map.move(
                  _map.camera.center,
                  (_map.camera.zoom + 1).clamp(6, 18),
                ),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 6),
              FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Zoom out',
                onPressed: () => _map.move(
                  _map.camera.center,
                  (_map.camera.zoom - 1).clamp(6, 18),
                ),
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 6),
              FloatingActionButton.small(
                heroTag: null,
                tooltip: 'My location',
                onPressed: _locate,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
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
    this.profile = 'car',
    this.tripControls,
  });
  final LatLng? initialPosition;
  final OfflineDestination? destination;
  final bool selectDestination;
  final String profile;
  final Widget? tripControls;
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
  final String _profile = 'car';
  String? _error;
  bool _routing = false, _following = true;
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
    if (!widget.selectDestination) {
      _gps();
    } else {
      _locateIfAllowed();
    }
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
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const FormatException(
          'Allow location access to use your current position.',
        );
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException(
          'Turn on location services for GPS navigation.',
        );
      }
      if (!mounted) return;
      Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 15),
            ),
          )
          .then((position) {
            if (mounted) _onPosition(position);
          })
          .catchError((Object _) {});
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (Object error) {
              if (mounted) {
                setState(
                  () => _error = offlineErrorMessage(
                    error,
                    'Check your location settings or try another destination.',
                  ),
                );
              }
            },
          );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = offlineErrorMessage(
            error,
            'Check your location settings or try another destination.',
          ),
        );
      }
    }
  }

  Future<void> _locateIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if ([
        LocationPermission.always,
        LocationPermission.whileInUse,
      ].contains(permission)) {
        _gps();
      }
    } catch (_) {}
  }

  void _onPosition(Position fix) {
    if (!mounted ||
        fix.isMocked ||
        !fix.accuracy.isFinite ||
        fix.accuracy > 30) {
      return;
    }
    final point = LatLng(fix.latitude, fix.longitude);
    final firstLocation = _position == null;
    setState(() {
      _position = point;
    });
    if (_following) {
      _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
    } else if (firstLocation && _destination == null) {
      _map.move(point, 14);
    }
    if (widget.selectDestination) return;
    if (_destination == null) return;
    if (_route == null) {
      if (!_routing &&
          (_lastRouteAttempt == null ||
              DateTime.now().difference(_lastRouteAttempt!).inSeconds >= 10)) {
        _calculate();
      }
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
      if (!_following) {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(45),
          ),
        );
      }
    } catch (error) {
      if (mounted && serial == _routeSequence) {
        setState(() {
          _error = offlineErrorMessage(
            error,
            'Check your location settings or try another destination.',
          );
          _route = null;
          _routePoints = [];
        });
      }
    } finally {
      if (mounted && serial == _routeSequence) setState(() => _routing = false);
    }
  }

  void _choose(LatLng point, String name) {
    FocusScope.of(context).unfocus();
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
      _destination = OfflineDestination(
        point.latitude,
        point.longitude,
        name,
        profile: _profile,
      );
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
        final found = await OfflineNavigationService.instance
            .request('search', {
              'query': query,
              if (_position != null) 'latitude': _position!.latitude,
              if (_position != null) 'longitude': _position!.longitude,
            });
        if (mounted && serial == _searchSequence) {
          setState(() => _matches = (found['places'] as List).cast<List>());
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = offlineErrorMessage(
              error,
              'Check your location settings or try another destination.',
            ),
          );
        }
      }
    });
  }

  void _category(String query) {
    _search.text = query;
    FocusScope.of(context).unfocus();
    _find(query);
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
    if (widget.tripControls != null) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            BundledRoadMap(
              controller: _map,
              initialCenter:
                  _position ?? _destination?.point ?? const LatLng(7.8, 80.7),
              initialZoom: _position == null && _destination == null ? 7 : 16,
              position: _position,
              destination: _destination?.point,
              route: _routePoints,
              onLocate: () {
                setState(() => _following = true);
                if (_position != null) _map.move(_position!, 16);
                _gps();
              },
              onUserMove: () {
                if (_following) setState(() => _following = false);
              },
            ),
            Positioned(
              top: 0,
              left: 12,
              right: 72,
              child: SafeArea(
                bottom: false,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back to trips',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                arrived
                                    ? 'You have arrived'
                                    : next?['text']?.toString() ??
                                          _destination?.name ??
                                          'Choose destination',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _routing
                                    ? 'Finding route...'
                                    : _route != null
                                    ? '${_distance(remaining)} remaining'
                                    : _position == null
                                    ? 'Finding your location...'
                                    : 'Offline GPS navigation',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Choose destination',
                          icon: const Icon(Icons.search),
                          onPressed: () async {
                            final destination =
                                await Navigator.push<OfflineDestination>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OfflineNavigationScreen(
                                      selectDestination: true,
                                      initialPosition: _position,
                                      destination: _destination,
                                    ),
                                  ),
                                );
                            if (destination != null && mounted) {
                              _choose(destination.point, destination.name);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    widget.tripControls!,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                hintText: 'Where to?',
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
                      leading: Icon(
                        BundledRoadMap.landmarkIcon(place[3] as String),
                      ),
                      title: Text(place[0].toString()),
                      subtitle: Text((place[3] as String).replaceAll('_', ' ')),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.train, size: 18),
                    label: const Text('Stations'),
                    onPressed: () => _category('station'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.local_gas_station, size: 18),
                    label: const Text('Fuel'),
                    onPressed: () => _category('fuel'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.local_hospital, size: 18),
                    label: const Text('Hospitals'),
                    onPressed: () => _category('hospital'),
                  ),
                ],
              ),
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
              onLandmarkSelected: (place) => _choose(place.point, place.name),
              onLocate: () {
                setState(() => _following = true);
                if (_position != null) _map.move(_position!, 16);
                _gps();
              },
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
                  if (!widget.selectDestination &&
                      _position == null &&
                      _error == null)
                    const Text('Finding your location...'),
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

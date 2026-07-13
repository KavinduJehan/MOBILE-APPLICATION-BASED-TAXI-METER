import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'profile_tab.dart';

const _defaultCenter = LatLng(6.9271, 79.8612);

const _places = <String, LatLng>{
  'Colombo': LatLng(6.9271, 79.8612),
  'Galle': LatLng(6.0535, 80.2210),
  'Kandy': LatLng(7.2906, 80.6337),
  'Matara': LatLng(5.9549, 80.5550),
  'Negombo': LatLng(7.2096, 79.8378),
  'Jaffna': LatLng(9.6615, 80.0255),
  'Trincomalee': LatLng(8.5874, 81.2152),
  'Badulla': LatLng(6.9934, 81.0550),
  'Ratnapura': LatLng(6.7056, 80.3847),
  'Kurunegala': LatLng(7.4867, 80.3647),
  'Nugegoda': LatLng(6.8649, 79.8997),
  'Dehiwala': LatLng(6.8566, 79.8655),
  'Mount Lavinia': LatLng(6.8301, 79.8801),
  'Maharagama': LatLng(6.8480, 79.9265),
  'Battaramulla': LatLng(6.9006, 79.9186),
  'Katunayake': LatLng(7.1697, 79.8841),
  'Kiribathgoda': LatLng(6.9804, 79.9297),
  'Gampaha': LatLng(7.0873, 80.0144),
};

class LocationSelectionResult {
  const LocationSelectionResult({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
  });

  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _dropFocusNode = FocusNode();
  StreamSubscription<Position>? _positionSub;

  LatLng _pickup = _defaultCenter;
  LatLng? _destination;
  LatLng? _liveLocation;
  String _pickupAddress = 'Your location';
  String? _destinationAddress;
  bool _editingPickup = false;
  bool _pickupChangedManually = false;
  bool _locating = true;
  bool _showMap = false;
  String? _locationMessage;
  List<_SavedPlace> _savedPlaces = const [];
  bool _loadingSavedPlaces = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _startLocation();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _dropFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _locationMessage = 'Location permission denied. Set pickup on map.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _applyLiveLocation(position, moveMap: true);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen(_applyLiveLocation);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationMessage = 'Could not read live location. Set pickup on map.';
      });
    }
  }

  void _applyLiveLocation(Position position, {bool moveMap = false}) {
    final point = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _liveLocation = point;
      _locating = false;
      _locationMessage = null;
      if (!_pickupChangedManually) {
        _pickup = point;
        _pickupAddress = 'Your location';
      }
    });
    if (moveMap && _showMap) {
      _mapController.move(point, 15);
    }
  }

  void _handleMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_editingPickup || _destination == null) {
        _pickup = point;
        _pickupChangedManually = true;
        _pickupAddress = 'Pinned pickup';
        _editingPickup = false;
      } else {
        _destination = point;
        _destinationAddress = _searchController.text.trim().isEmpty
            ? 'Pinned destination'
            : _searchController.text.trim();
      }
    });
  }

  Future<void> _loadSavedPlaces() async {
    setState(() => _loadingSavedPlaces = true);
    try {
      final response = await ApiService.getSavedPlaces();
      if (!mounted) return;
      setState(() {
        _savedPlaces = _SavedPlace.listFromResponse(response.data);
        _loadingSavedPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSavedPlaces = false);
    }
  }

  Future<void> _openSavedPlaces() async {
    if (_loadingSavedPlaces) return;
    if (_savedPlaces.isEmpty) {
      await _loadSavedPlaces();
      if (!mounted) return;
    }

    final updated = await Navigator.push<List<SavedAddress>>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedPlacesScreen(
          addresses: _savedPlaces
              .map((place) => place.toSavedAddress())
              .toList(),
        ),
      ),
    );
    if (updated == null) return;

    setState(() {
      _loadingSavedPlaces = true;
      _savedPlaces = updated.map(_SavedPlace.fromSavedAddress).toList();
    });

    try {
      final response = await ApiService.updateSavedPlaces(
        updated.map((address) => address.toJson()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _savedPlaces = _SavedPlace.listFromResponse(response.data);
        _loadingSavedPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSavedPlaces = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. Sync failed, try again online.'),
        ),
      );
    }
  }

  void _selectSavedPlace(_SavedPlace place) {
    final point = place.point ?? _pointForSavedPlace(place);
    _searchController.text = place.address;
    if (point == null) {
      setState(() {
        _destinationAddress = place.address;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set this saved place on the map to continue.'),
        ),
      );
      _openMapForPinning();
      return;
    }
    _selectDestination(place.address, point);
  }

  LatLng? _pointForSavedPlace(_SavedPlace place) {
    final source = '${place.label} ${place.address}'.toLowerCase();
    for (final entry in _places.entries) {
      if (source.contains(entry.key.toLowerCase())) return entry.value;
    }
    return null;
  }

  void _selectDestination(String name, LatLng point) {
    _searchController.text = name;
    setState(() {
      _destination = point;
      _destinationAddress = name;
      _editingPickup = false;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mapController.move(point, 14),
    );
  }

  void _openMapForPinning() {
    setState(() => _showMap = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        _destination ?? _pickup,
        _destination == null ? 15 : 14,
      );
    });
  }

  void _openPickupForPinning() {
    _dropFocusNode.unfocus();
    setState(() {
      _editingPickup = true;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mapController.move(_pickup, 15),
    );
  }

  void _clearDrop() {
    _searchController.clear();
    setState(() {
      _destination = null;
      _destinationAddress = null;
    });
    _dropFocusNode.requestFocus();
  }

  void _confirm() {
    final destination = _destination;
    final destinationAddress = _destinationAddress;
    if (destination == null || destinationAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a destination first.')),
      );
      return;
    }

    Navigator.pop(
      context,
      LocationSelectionResult(
        pickupAddress: _pickupAddress,
        pickupLat: _pickup.latitude,
        pickupLng: _pickup.longitude,
        destinationAddress: destinationAddress,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
      ),
    );
  }

  List<MapEntry<String, LatLng>> get _suggestions {
    final query = _searchController.text.trim().toLowerCase();
    return _places.entries
        .where(
          (entry) => query.isEmpty || entry.key.toLowerCase().contains(query),
        )
        .take(7)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_showMap) return _buildMapView();
    return _buildSearchView();
  }

  Widget _buildSearchView() {
    final quickPlaces = _savedPlaces.take(3).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 15,
              onTap: (_, point) {
                setState(() {
                  _destination = point;
                  _destinationAddress = _searchController.text.trim().isEmpty
                      ? 'Pinned destination'
                      : _searchController.text.trim();
                  _showMap = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ridex.customer',
              ),
              MarkerLayer(
                markers: [
                  if (_liveLocation != null)
                    Marker(
                      point: _liveLocation!,
                      width: 34,
                      height: 34,
                      child: const Icon(
                        Icons.my_location,
                        color: AppTheme.primaryBlue,
                        size: 26,
                      ),
                    ),
                  Marker(
                    point: _pickup,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppTheme.successGreen,
                      size: 42,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    tooltip: 'Back',
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 190,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                onPressed: _openMapForPinning,
                icon: const Icon(
                  Icons.my_location,
                  color: AppTheme.primaryBlue,
                ),
                tooltip: 'Set on map',
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MapSearchPanel(
                      pickupAddress: _locating
                          ? 'Detecting location...'
                          : _pickupAddress,
                      locationMessage: _locationMessage,
                      controller: _searchController,
                      focusNode: _dropFocusNode,
                      onEditPickup: _openPickupForPinning,
                      onClearDrop: _clearDrop,
                      onOpenMap: _openMapForPinning,
                    ),
                    if (_suggestions.isNotEmpty ||
                        _searchController.text.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _suggestions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No matching locations found',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = _suggestions[index];
                                  return _LightSuggestionTile(
                                    title: entry.key,
                                    subtitle: 'Sri Lanka',
                                    onTap: () => _selectDestination(
                                      entry.key,
                                      entry.value,
                                    ),
                                  );
                                },
                              ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickDestinationCard(
                            icon: Icons.home_outlined,
                            label: quickPlaces.isNotEmpty
                                ? quickPlaces[0].label
                                : 'Home',
                            subtitle: quickPlaces.isNotEmpty
                                ? quickPlaces[0].address
                                : 'Saved places',
                            onTap: quickPlaces.isNotEmpty
                                ? () => _selectSavedPlace(quickPlaces[0])
                                : _openSavedPlaces,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickDestinationCard(
                            icon: Icons.work_outline,
                            label: quickPlaces.length > 1
                                ? quickPlaces[1].label
                                : 'Work',
                            subtitle: quickPlaces.length > 1
                                ? quickPlaces[1].address
                                : 'Add work',
                            onTap: quickPlaces.length > 1
                                ? () => _selectSavedPlace(quickPlaces[1])
                                : _openSavedPlaces,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickDestinationCard(
                            icon: Icons.favorite_border,
                            label: 'Saved',
                            subtitle: _loadingSavedPlaces
                                ? 'Loading...'
                                : '${_savedPlaces.length} places',
                            onTap: _openSavedPlaces,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _showMap = false);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _dropFocusNode.requestFocus(),
            );
          },
        ),
        title: const Text('Set location on map'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Confirm')),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 13,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ridex.customer',
              ),
              MarkerLayer(
                markers: [
                  if (_liveLocation != null)
                    Marker(
                      point: _liveLocation!,
                      width: 34,
                      height: 34,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 26,
                      ),
                    ),
                  Marker(
                    point: _pickup,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppTheme.successGreen,
                      size: 42,
                    ),
                  ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 42,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _MapConfirmPanel(
              pickupAddress: _pickupAddress,
              destinationAddress: _destinationAddress,
              editingPickup: _editingPickup,
              onEditPickup: () => setState(() => _editingPickup = true),
              onUseLiveLocation: _liveLocation == null
                  ? null
                  : () {
                      setState(() {
                        _pickup = _liveLocation!;
                        _pickupAddress = 'Your location';
                        _pickupChangedManually = false;
                        _editingPickup = false;
                      });
                      _mapController.move(_pickup, 15);
                    },
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSearchPanel extends StatelessWidget {
  const _MapSearchPanel({
    required this.pickupAddress,
    required this.locationMessage,
    required this.controller,
    required this.focusNode,
    required this.onEditPickup,
    required this.onClearDrop,
    required this.onOpenMap,
  });

  final String pickupAddress;
  final String? locationMessage;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEditPickup;
  final VoidCallback onClearDrop;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: const [
                Icon(Icons.circle, color: Color(0xFFFFB33F), size: 10),
                SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: VerticalDivider(
                    color: Color(0xFFE0E3E7),
                    thickness: 2,
                    width: 8,
                  ),
                ),
                SizedBox(height: 10),
                Icon(Icons.trip_origin, color: Color(0xFFFFB33F), size: 15),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pick up',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Pickup location, $pickupAddress. Change pickup',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onEditPickup,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                pickupAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (locationMessage != null)
                              Tooltip(
                                message: locationMessage!,
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFFFB33F),
                                  size: 20,
                                ),
                              )
                            else
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF9AA0A6),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFE8EAEE)),
                  Text(
                    'Drop off',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.only(top: 2),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Where to?',
                            hintStyle: TextStyle(
                              color: Color(0xFF9AA0A6),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: controller.text.isEmpty
                            ? onOpenMap
                            : onClearDrop,
                        icon: Icon(
                          controller.text.isEmpty ? Icons.add : Icons.close,
                          color: Colors.black54,
                        ),
                        tooltip: controller.text.isEmpty
                            ? 'Set on map'
                            : 'Clear destination',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDestinationCard extends StatelessWidget {
  const _QuickDestinationCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFFFFB33F,
                ).withValues(alpha: 0.16),
                child: Icon(icon, color: const Color(0xFFFFA51F), size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightSuggestionTile extends StatelessWidget {
  const _LightSuggestionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: const Icon(Icons.place_outlined, color: AppTheme.primaryBlue),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.black45)),
      trailing: const Icon(Icons.chevron_right, color: Colors.black38),
    );
  }
}

class _SavedPlace {
  const _SavedPlace({
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });

  final String label;
  final String address;
  final double? lat;
  final double? lng;

  LatLng? get point => lat == null || lng == null ? null : LatLng(lat!, lng!);

  factory _SavedPlace.fromJson(Map<String, dynamic> json) {
    return _SavedPlace(
      label: (json['label'] ?? 'Saved place').toString(),
      address: (json['address'] ?? '').toString(),
      lat: _readDouble(json['lat']),
      lng: _readDouble(json['lng']),
    );
  }

  factory _SavedPlace.fromSavedAddress(SavedAddress address) {
    return _SavedPlace(label: address.label, address: address.address);
  }

  SavedAddress toSavedAddress() {
    return SavedAddress(label: label, address: address);
  }

  static List<_SavedPlace> listFromResponse(Object? data) {
    Object? listSource;
    if (data is Map) {
      listSource = data['savedPlaces'] ?? data['data'];
    } else {
      listSource = data;
    }
    if (listSource is! List) return const [];
    return listSource
        .whereType<Map>()
        .map((item) => _SavedPlace.fromJson(Map<String, dynamic>.from(item)))
        .where((place) => place.address.trim().isNotEmpty)
        .toList();
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _MapConfirmPanel extends StatelessWidget {
  const _MapConfirmPanel({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.editingPickup,
    required this.onEditPickup,
    required this.onUseLiveLocation,
    required this.onConfirm,
  });

  final String pickupAddress;
  final String? destinationAddress;
  final bool editingPickup;
  final VoidCallback onEditPickup;
  final VoidCallback? onUseLiveLocation;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MapLocationRow(
              icon: Icons.trip_origin,
              color: AppTheme.successGreen,
              label: 'Pickup',
              value: editingPickup
                  ? 'Tap the map to set pickup'
                  : pickupAddress,
              trailing: TextButton(
                onPressed: onEditPickup,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),
            _MapLocationRow(
              icon: Icons.location_on,
              color: Colors.redAccent,
              label: 'Destination',
              value: destinationAddress ?? 'Tap the map to set destination',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onUseLiveLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Use live location',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirm locations'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLocationRow extends StatelessWidget {
  const _MapLocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

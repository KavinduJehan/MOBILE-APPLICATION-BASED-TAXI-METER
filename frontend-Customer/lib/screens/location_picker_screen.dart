import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _TripTypeHeader(onClose: () => Navigator.pop(context)),
            _PickupDropPanel(
              pickupAddress: _locating
                  ? 'Detecting location...'
                  : _pickupAddress,
              locationMessage: _locationMessage,
              controller: _searchController,
              focusNode: _dropFocusNode,
              onClearDrop: _clearDrop,
              onOpenMap: _openMapForPinning,
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _ActionTile(
                    icon: Icons.favorite_border,
                    title: 'Saved Addresses',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () {},
                  ),
                  _ActionTile(
                    icon: Icons.pin_drop_outlined,
                    title: 'Set location on map',
                    emphasized: true,
                    onTap: _openMapForPinning,
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.work_outline,
                    title: 'Add Work',
                    iconColor: Colors.orangeAccent,
                    trailing: const Icon(Icons.add, color: Colors.white70),
                    onTap: () {},
                  ),
                  _SavedLocationTile(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    subtitle: '543, Galedanda Road, Gonawala, Gampaha',
                    onTap: () =>
                        _selectDestination('Gampaha', _places['Gampaha']!),
                  ),
                  _SavedLocationTile(
                    icon: Icons.access_time,
                    title: 'Rovinta electronics',
                    subtitle: 'Kandy Road, Kiribathgoda, Sri Lanka',
                    onTap: () => _selectDestination(
                      'Kiribathgoda',
                      _places['Kiribathgoda']!,
                    ),
                  ),
                  if (_suggestions.isNotEmpty) const _SectionDivider(),
                  ..._suggestions.map(
                    (entry) => _SuggestionTile(
                      title: entry.key,
                      subtitle: 'Sri Lanka',
                      onTap: () => _selectDestination(entry.key, entry.value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _TripTypeHeader extends StatelessWidget {
  const _TripTypeHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(color: Color(0xFF0E1422)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: double.infinity,
              color: AppTheme.surfaceAlt,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.check,
                      color: AppTheme.background,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'One way',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.white38,
                  size: 30,
                ),
                SizedBox(width: 12),
                Text(
                  'Return trip*',
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PickupDropPanel extends StatelessWidget {
  const _PickupDropPanel({
    required this.pickupAddress,
    required this.locationMessage,
    required this.controller,
    required this.focusNode,
    required this.onClearDrop,
    required this.onOpenMap,
  });

  final String pickupAddress;
  final String? locationMessage;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClearDrop;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: Color(0xFF202938))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'PICKUP',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 2, height: 28, color: Colors.white24),
                const SizedBox(height: 14),
                const Text(
                  'DROP',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pickupAddress,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (locationMessage != null)
                      IconButton(
                        onPressed: onOpenMap,
                        icon: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        ),
                        tooltip: locationMessage,
                      ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFF2A3446)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Where are you going?',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.text.isEmpty
                          ? onOpenMap
                          : onClearDrop,
                      icon: Icon(
                        controller.text.isEmpty ? Icons.add : Icons.close,
                        color: Colors.white70,
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
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.iconColor = Colors.white,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color iconColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 18,
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
      trailing: trailing,
      shape: const Border(bottom: BorderSide(color: Color(0xFF202938))),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  const _SavedLocationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 14,
      leading: CircleAvatar(
        backgroundColor: Colors.orangeAccent.withValues(alpha: 0.12),
        child: Icon(icon, color: Colors.orangeAccent),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: const Icon(Icons.more_vert, color: Colors.white54),
      shape: const Border(bottom: BorderSide(color: Color(0xFF202938))),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
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
      leading: const Icon(Icons.place_outlined, color: AppTheme.primaryBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      shape: const Border(bottom: BorderSide(color: Color(0xFF202938))),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 10, color: const Color(0xFF070B12));
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

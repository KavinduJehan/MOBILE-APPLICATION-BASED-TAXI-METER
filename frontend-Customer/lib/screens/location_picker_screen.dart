import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/google_maps_availability.dart';
import 'profile_tab.dart';

const _defaultCenter = LatLng(6.9271, 79.8612);

String _newPlacesSessionToken() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

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
  GoogleMapController? _mapController;
  final _pickupSearchController = TextEditingController();
  final _searchController = TextEditingController();
  final _pickupFocusNode = FocusNode();
  final _dropFocusNode = FocusNode();
  StreamSubscription<Position>? _positionSub;
  Future<void>? _savedPlacesLoad;
  Timer? _placeSearchDebounce;
  List<_PlaceSuggestion> _remoteSuggestions = const [];
  bool _searchingPlaces = false;
  bool _resolvingPlace = false;
  bool _suppressSearch = false;
  int _placeSearchGeneration = 0;
  String? _placeSearchError;
  String _placesSessionToken = _newPlacesSessionToken();
  List<_RecentPlace> _recentPlaces = const [];
  bool _resolvingLiveAddress = false;

  LatLng _pickup = _defaultCenter;
  LatLng? _destination;
  LatLng? _liveLocation;
  String _pickupAddress = 'Detecting live location...';
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
    _pickupSearchController.addListener(_handleSearchTextChanged);
    _searchController.addListener(_handleSearchTextChanged);
    _pickupFocusNode.addListener(_handlePickupFocus);
    _dropFocusNode.addListener(_handleDropFocus);
    _startLocation();
    _refreshSavedPlaces();
    _loadRecentPlaces();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionSub?.cancel();
    _placeSearchDebounce?.cancel();
    _pickupSearchController
      ..removeListener(_handleSearchTextChanged)
      ..dispose();
    _searchController
      ..removeListener(_handleSearchTextChanged)
      ..dispose();
    _pickupFocusNode
      ..removeListener(_handlePickupFocus)
      ..dispose();
    _dropFocusNode
      ..removeListener(_handleDropFocus)
      ..dispose();
    super.dispose();
  }

  void _handlePickupFocus() {
    if (!mounted) return;
    setState(() {
      if (_pickupFocusNode.hasFocus) _editingPickup = true;
    });
    if (_pickupFocusNode.hasFocus) _schedulePlaceSearch();
  }

  void _handleDropFocus() {
    if (!mounted) return;
    setState(() {
      if (_dropFocusNode.hasFocus) _editingPickup = false;
    });
    if (_dropFocusNode.hasFocus) _schedulePlaceSearch();
  }

  void _handleSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_suppressSearch) _schedulePlaceSearch();
  }

  void _setSearchText(TextEditingController controller, String value) {
    _suppressSearch = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _suppressSearch = false;
  }

  void _schedulePlaceSearch() {
    _placeSearchDebounce?.cancel();
    final controller = _editingPickup
        ? _pickupSearchController
        : _searchController;
    final query = controller.text.trim();
    final generation = ++_placeSearchGeneration;

    if (query.length < 2) {
      setState(() {
        _remoteSuggestions = const [];
        _searchingPlaces = false;
        _placeSearchError = null;
      });
      return;
    }

    setState(() {
      _searchingPlaces = true;
      _placeSearchError = null;
    });
    _placeSearchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _performPlaceSearch(query, generation),
    );
  }

  Future<void> _performPlaceSearch(String query, int generation) async {
    try {
      final response = await ApiService.autocompletePlaces(
        input: query,
        sessionToken: _placesSessionToken,
        latitude: _pickup.latitude,
        longitude: _pickup.longitude,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final items = data['suggestions'] is List
          ? (data['suggestions'] as List)
                .whereType<Map>()
                .map(
                  (item) => _PlaceSuggestion.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.placeId != null)
                .toList()
          : <_PlaceSuggestion>[];
      if (!mounted || generation != _placeSearchGeneration) return;
      setState(() {
        _remoteSuggestions = items;
        _placeSearchError = null;
      });
    } on DioException catch (error) {
      if (!mounted || generation != _placeSearchGeneration) return;
      setState(() {
        _remoteSuggestions = const [];
        _placeSearchError = error.error?.toString() ?? 'Location search failed';
      });
    } catch (_) {
      if (!mounted || generation != _placeSearchGeneration) return;
      setState(() {
        _remoteSuggestions = const [];
        _placeSearchError = 'Location search failed';
      });
    } finally {
      if (mounted && generation == _placeSearchGeneration) {
        setState(() => _searchingPlaces = false);
      }
    }
  }

  Future<void> _selectPlaceSuggestion(_PlaceSuggestion suggestion) async {
    final point = suggestion.point;
    if (point != null) {
      unawaited(
        _rememberRecent(
          _RecentPlace(
            title: suggestion.title,
            address: suggestion.description,
            point: point,
            placeId: suggestion.placeId,
          ),
        ),
      );
      _selectResolvedPlace(suggestion.description, point, _editingPickup);
      return;
    }

    final placeId = suggestion.placeId;
    if (placeId == null || _resolvingPlace) return;
    final selectingPickup = _editingPickup;
    setState(() => _resolvingPlace = true);

    try {
      final response = await ApiService.getPlaceDetails(
        placeId: placeId,
        sessionToken: _placesSessionToken,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final latitude = _readCoordinate(data['lat']);
      final longitude = _readCoordinate(data['lng']);
      if (latitude == null || longitude == null) {
        throw const FormatException('Selected location has no coordinates');
      }
      final address =
          (data['address'] ?? data['name'] ?? suggestion.description)
              .toString();
      if (!mounted) return;
      unawaited(
        _rememberRecent(
          _RecentPlace(
            title: (data['name'] ?? suggestion.title).toString(),
            address: address,
            point: LatLng(latitude, longitude),
            placeId: placeId,
          ),
        ),
      );
      _selectResolvedPlace(
        address,
        LatLng(latitude, longitude),
        selectingPickup,
      );
      _placesSessionToken = _newPlacesSessionToken();
      _remoteSuggestions = const [];
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.error?.toString() ?? 'Could not load the selected location',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the selected location')),
      );
    } finally {
      if (mounted) setState(() => _resolvingPlace = false);
    }
  }

  void _selectResolvedPlace(String name, LatLng point, bool pickup) {
    if (pickup) {
      _selectPickup(name, point);
    } else {
      _selectDestination(name, point);
    }
  }

  static double? _readCoordinate(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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

  void _moveMap(LatLng point, double zoom) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, zoom));
  }

  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _applyLiveLocation(Position position, {bool moveMap = false}) {
    final point = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    final shouldResolveAddress =
        !_pickupChangedManually &&
        (_pickupAddress == 'Detecting live location...' ||
            _pickupAddress == 'Location fetched');
    setState(() {
      _liveLocation = point;
      _locating = false;
      _locationMessage = null;
      if (!_pickupChangedManually) {
        _pickup = point;
        _pickupAddress = 'Location fetched';
      }
    });
    if (shouldResolveAddress) unawaited(_resolveLivePickupAddress(point));
    if (moveMap) _moveMap(point, 15);
  }

  Future<void> _resolveLivePickupAddress(LatLng point) async {
    if (_resolvingLiveAddress) return;
    _resolvingLiveAddress = true;
    try {
      final response = await ApiService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final address = data['address']?.toString().trim();
      if (!mounted ||
          _pickupChangedManually ||
          address == null ||
          address.isEmpty) {
        return;
      }
      final isCurrentPoint =
          (_pickup.latitude - point.latitude).abs() < 0.0005 &&
          (_pickup.longitude - point.longitude).abs() < 0.0005;
      if (isCurrentPoint) setState(() => _pickupAddress = address);
    } catch (_) {
      // Coordinates remain a valid pickup even when an address is unavailable.
    } finally {
      _resolvingLiveAddress = false;
    }
  }

  String get _recentPlacesCacheKey {
    final customerId = context.read<AuthProvider>().customer?.id ?? 'guest';
    return 'location_picker_recent_places_$customerId';
  }

  Future<void> _loadRecentPlaces() async {
    final cacheKey = _recentPlacesCacheKey;
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(cacheKey);
    if (!mounted || source == null) return;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return;
      setState(() {
        _recentPlaces = decoded
            .whereType<Map>()
            .map(
              (item) => _RecentPlace.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      });
    } catch (_) {
      // Ignore invalid local history.
    }
  }

  Future<void> _rememberRecent(_RecentPlace place) async {
    final cacheKey = _recentPlacesCacheKey;
    final updated = [
      place,
      ..._recentPlaces.where(
        (item) => place.placeId == null
            ? item.address.toLowerCase() != place.address.toLowerCase()
            : item.placeId != place.placeId,
      ),
    ].take(8).toList();
    if (mounted) setState(() => _recentPlaces = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cacheKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _clearRecentPlaces() async {
    final cacheKey = _recentPlacesCacheKey;
    setState(() => _recentPlaces = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
  }

  void _selectRecentPlace(_RecentPlace place) {
    unawaited(_rememberRecent(place));
    _selectResolvedPlace(place.address, place.point, _editingPickup);
  }

  void _handleMapTap(LatLng point) {
    if (_editingPickup) {
      _setSearchText(_pickupSearchController, 'Pinned pickup');
      setState(() {
        _pickup = point;
        _pickupChangedManually = true;
        _pickupAddress = 'Pinned pickup';
        _editingPickup = false;
      });
      return;
    }

    final destinationName = _searchController.text.trim().isEmpty
        ? 'Pinned destination'
        : _searchController.text.trim();
    _setSearchText(_searchController, destinationName);
    setState(() {
      _destination = point;
      _destinationAddress = destinationName;
    });
  }

  Future<void> _refreshSavedPlaces() {
    final activeLoad = _savedPlacesLoad;
    if (activeLoad != null) return activeLoad;

    final load = _loadSavedPlaces();
    _savedPlacesLoad = load;
    load.whenComplete(() {
      if (identical(_savedPlacesLoad, load)) _savedPlacesLoad = null;
    });
    return load;
  }

  String get _savedPlacesCacheKey {
    final customerId = context.read<AuthProvider>().customer?.id ?? 'guest';
    return ['location_picker_saved_places_', customerId].join();
  }

  Future<void> _cacheSavedPlaces(
    List<_SavedPlace> places, {
    required bool needsSync,
  }) async {
    final key = _savedPlacesCacheKey;
    final syncKey = [key, '_needs_sync'].join();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(places.map((place) => place.toJson()).toList()),
    );
    await prefs.setBool(syncKey, needsSync);
  }

  Future<void> _loadSavedPlaces() async {
    setState(() => _loadingSavedPlaces = true);
    final key = _savedPlacesCacheKey;
    final syncKey = [key, '_needs_sync'].join();
    final prefs = await SharedPreferences.getInstance();
    final cachedSource = prefs.getString(key);
    final cachedPlaces = _SavedPlace.listFromCache(cachedSource);
    final needsSync = prefs.getBool(syncKey) ?? false;

    if (mounted && cachedPlaces.isNotEmpty) {
      setState(() => _savedPlaces = cachedPlaces);
    }

    try {
      final response = needsSync
          ? await ApiService.updateSavedPlaces(
              cachedPlaces.map((place) => place.toJson()).toList(),
            )
          : await ApiService.getSavedPlaces();
      final databasePlaces = _SavedPlace.listFromResponse(response.data);
      await _cacheSavedPlaces(databasePlaces, needsSync: false);
      if (!mounted) return;
      setState(() {
        _savedPlaces = databasePlaces;
        _loadingSavedPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSavedPlaces = false);
    }
  }

  Future<void> _openSavedPlaces() async {
    await _refreshSavedPlaces();
    if (!mounted) return;

    final result = await Navigator.push<SavedPlacesResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedPlacesScreen(
          addresses: _savedPlaces
              .map((place) => place.toSavedAddress())
              .toList(),
          allowSelection: true,
        ),
      ),
    );
    if (result == null) return;
    final updated = result.addresses;

    setState(() {
      _loadingSavedPlaces = true;
      _savedPlaces = updated.map(_SavedPlace.fromSavedAddress).toList();
    });
    await _cacheSavedPlaces(_savedPlaces, needsSync: true);

    try {
      final response = await ApiService.updateSavedPlaces(
        updated.map((address) => address.toJson()).toList(),
      );
      final databasePlaces = _SavedPlace.listFromResponse(response.data);
      await _cacheSavedPlaces(databasePlaces, needsSync: false);
      if (!mounted) return;
      setState(() {
        _savedPlaces = databasePlaces;
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

    final selected = result.selectedAddress;
    if (selected != null && mounted) {
      _selectSavedPlace(_SavedPlace.fromSavedAddress(selected));
    }
  }

  void _selectSavedPlace(_SavedPlace place) {
    final point = place.point;
    if (point == null) {
      if (_editingPickup) {
        _setSearchText(_pickupSearchController, place.address);
      } else {
        _setSearchText(_searchController, place.address);
        setState(() => _destinationAddress = place.address);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Set this ${_editingPickup ? 'pickup' : 'destination'} on the map to continue.',
          ),
        ),
      );
      if (_editingPickup) {
        _openPickupForPinning();
      } else {
        _openMapForPinning();
      }
      return;
    }
    if (_editingPickup) {
      _selectPickup(place.address, point);
    } else {
      _selectDestination(place.address, point);
    }
  }

  void _selectPickup(String name, LatLng point) {
    _setSearchText(_pickupSearchController, name);
    _pickupFocusNode.unfocus();
    setState(() {
      _pickup = point;
      _pickupAddress = name;
      _pickupChangedManually = true;
      _editingPickup = false;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveMap(point, 15));
  }

  void _selectDestination(String name, LatLng point) {
    _setSearchText(_searchController, name);
    _pickupFocusNode.unfocus();
    setState(() {
      _destination = point;
      _destinationAddress = name;
      _editingPickup = false;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveMap(point, 14));
  }

  void _openMapForPinning() {
    _pickupFocusNode.unfocus();
    setState(() {
      _editingPickup = false;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveMap(_destination ?? _pickup, _destination == null ? 15 : 14);
    });
  }

  void _openPickupForPinning() {
    _pickupFocusNode.unfocus();
    _dropFocusNode.unfocus();
    setState(() {
      _editingPickup = true;
      _showMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveMap(_pickup, 15));
  }

  void _clearPickup() {
    _pickupSearchController.clear();
    final liveLocation = _liveLocation;
    setState(() {
      _pickup = liveLocation ?? _defaultCenter;
      _pickupAddress = liveLocation == null
          ? 'Choose pickup'
          : 'Location fetched';
      _pickupChangedManually = false;
      _editingPickup = true;
    });
    if (liveLocation != null) {
      unawaited(_resolveLivePickupAddress(liveLocation));
    }
    _pickupFocusNode.requestFocus();
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

  List<_PlaceSuggestion> get _suggestions {
    final activeController = _editingPickup
        ? _pickupSearchController
        : _searchController;
    final query = activeController.text.trim().toLowerCase();
    if (query.length < 2) return const [];
    // Typed results must come from Google Places. The old local fallback only
    // contained districts and made valid roads, shops, and landmarks invisible.
    return _remoteSuggestions.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_showMap) return _buildMapView();
    return _buildSearchView();
  }

  Widget _buildSearchView() {
    final quickPlaces = _savedPlaces.take(3).toList();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final searchMode = _pickupFocusNode.hasFocus || _dropFocusNode.hasFocus;
    final activeSearchText = _editingPickup
        ? _pickupSearchController.text
        : _searchController.text;
    // Keep the route selector higher over the map like the booking reference.
    // Remove the extra lift while typing so the keyboard cannot squeeze it.
    final panelLift = !searchMode && keyboardInset == 0 ? 56.0 : 0.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          if (isGoogleMapsAvailable)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _pickup, zoom: 15),
              onMapCreated: _handleMapCreated,
              onTap: (point) {
                _handleMapTap(point);
                setState(() => _showMap = true);
              },
              markers: {
                if (_liveLocation != null)
                  Marker(
                    markerId: const MarkerId('live-location'),
                    position: _liveLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  ),
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _pickup,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else
            const _MapUnavailableBackground(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: AppTheme.surface,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                  ),
                ),
              ),
            ),
          ),
          if (!searchMode)
            Positioned(
              right: 16,
              bottom: keyboardInset + panelLift + 190,
              child: Material(
                color: AppTheme.surface,
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
            alignment: searchMode
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: SafeArea(
              top: searchMode,
              child: Padding(
                padding: searchMode
                    ? EdgeInsets.fromLTRB(16, 72, 16, 12 + keyboardInset)
                    : EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16 + keyboardInset + panelLift,
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
                      pickupController: _pickupSearchController,
                      dropController: _searchController,
                      pickupFocusNode: _pickupFocusNode,
                      dropFocusNode: _dropFocusNode,
                      onSearchPickup: () => setState(() {
                        _editingPickup = true;
                      }),
                      onSearchDrop: () => setState(() {
                        _editingPickup = false;
                      }),
                      onClearPickup: _clearPickup,
                      onClearDrop: _clearDrop,
                      onOpenPickupMap: _openPickupForPinning,
                      onOpenDropMap: _openMapForPinning,
                    ),
                    if (_searchingPlaces || _resolvingPlace)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_placeSearchError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _placeSearchError!,
                          style: const TextStyle(
                            color: Color(0xFFFFB33F),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_suggestions.isNotEmpty ||
                        (_editingPickup
                                ? _pickupSearchController.text
                                : _searchController.text)
                            .isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
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
                                  style: TextStyle(color: AppTheme.mutedText),
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
                                    title: entry.title,
                                    subtitle: entry.subtitle,
                                    onTap: _resolvingPlace
                                        ? () {}
                                        : () => _selectPlaceSuggestion(entry),
                                  );
                                },
                              ),
                      ),
                    if (_remoteSuggestions.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Powered by Google',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (searchMode && activeSearchText.trim().isEmpty)
                      _RecentPlacesPanel(
                        places: _recentPlaces,
                        onSelected: _selectRecentPlace,
                        onClear: _clearRecentPlaces,
                      ),
                    if (!searchMode) ...[
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
        title: const Text('Confirm locations'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Find Driver')),
        ],
      ),
      body: Stack(
        children: [
          if (isGoogleMapsAvailable)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _pickup, zoom: 13),
              onMapCreated: _handleMapCreated,
              onTap: _handleMapTap,
              markers: {
                if (_liveLocation != null)
                  Marker(
                    markerId: const MarkerId('live-location'),
                    position: _liveLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  ),
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _pickup,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
                if (_destination != null)
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: _destination!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else
            const _MapUnavailableBackground(),
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
                      _pickupSearchController.clear();
                      setState(() {
                        _pickup = _liveLocation!;
                        _pickupAddress = 'Your location';
                        _pickupChangedManually = false;
                        _editingPickup = false;
                      });
                      _moveMap(_pickup, 15);
                    },
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapUnavailableBackground extends StatelessWidget {
  const _MapUnavailableBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.background,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Map preview is unavailable. You can still choose a location below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _MapSearchPanel extends StatelessWidget {
  const _MapSearchPanel({
    required this.pickupAddress,
    required this.locationMessage,
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.onSearchPickup,
    required this.onSearchDrop,
    required this.onClearPickup,
    required this.onClearDrop,
    required this.onOpenPickupMap,
    required this.onOpenDropMap,
  });

  final String pickupAddress;
  final String? locationMessage;
  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final VoidCallback onSearchPickup;
  final VoidCallback onSearchDrop;
  final VoidCallback onClearPickup;
  final VoidCallback onClearDrop;
  final VoidCallback onOpenPickupMap;
  final VoidCallback onOpenDropMap;

  @override
  Widget build(BuildContext context) {
    const inputStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    const hintStyle = TextStyle(
      color: AppTheme.mutedText,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              children: [
                Icon(Icons.circle, color: AppTheme.actionBlue, size: 10),
                SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: VerticalDivider(
                    color: AppTheme.border,
                    thickness: 2,
                    width: 8,
                  ),
                ),
                SizedBox(height: 10),
                Icon(Icons.trip_origin, color: AppTheme.accent, size: 15),
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
                      color: AppTheme.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pickupController,
                          focusNode: pickupFocusNode,
                          onTap: onSearchPickup,
                          style: inputStyle,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.only(top: 2),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: pickupAddress,
                            hintStyle: hintStyle,
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
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: pickupController.text.isEmpty
                            ? onOpenPickupMap
                            : onClearPickup,
                        icon: Icon(
                          pickupController.text.isEmpty
                              ? Icons.map_outlined
                              : Icons.close,
                          color: AppTheme.accent,
                        ),
                        tooltip: pickupController.text.isEmpty
                            ? 'Set pickup on map'
                            : 'Clear pickup',
                      ),
                    ],
                  ),
                  const Divider(height: 18, color: AppTheme.border),
                  Text(
                    'Drop off',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dropController,
                          focusNode: dropFocusNode,
                          onTap: onSearchDrop,
                          style: inputStyle,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.only(top: 2),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Where to?',
                            hintStyle: hintStyle,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: dropController.text.isEmpty
                            ? onOpenDropMap
                            : onClearDrop,
                        icon: Icon(
                          dropController.text.isEmpty
                              ? Icons.map_outlined
                              : Icons.close,
                          color: AppTheme.accent,
                        ),
                        tooltip: dropController.text.isEmpty
                            ? 'Set destination on map'
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

class _RecentPlacesPanel extends StatelessWidget {
  const _RecentPlacesPanel({
    required this.places,
    required this.onSelected,
    required this.onClear,
  });

  final List<_RecentPlace> places;
  final ValueChanged<_RecentPlace> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (places.isNotEmpty)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (places.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Text(
                'Places you search and select will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: places.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return ListTile(
                    dense: true,
                    onTap: () => onSelected(place),
                    leading: const CircleAvatar(
                      radius: 15,
                      backgroundColor: AppTheme.surfaceAlt,
                      child: Icon(
                        Icons.history_rounded,
                        size: 17,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    title: Text(
                      place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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
      color: AppTheme.surface,
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
                backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
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
                style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.description,
    this.placeId,
    this.point,
  });

  factory _PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final description = (json['description'] ?? '').toString();
    final secondaryText = (json['secondaryText'] ?? 'Sri Lanka').toString();
    final distanceMeters = _readJsonDouble(json['distanceMeters']);
    final latitude = _readJsonDouble(json['lat']);
    final longitude = _readJsonDouble(json['lng']);
    return _PlaceSuggestion(
      title: (json['mainText'] ?? description).toString(),
      subtitle: distanceMeters == null
          ? secondaryText
          : '$secondaryText  •  ${_formatDistance(distanceMeters)}',
      description: description,
      placeId: json['placeId']?.toString(),
      point: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
    );
  }

  static double? _readJsonDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  final String title;
  final String subtitle;
  final String description;
  final String? placeId;
  final LatLng? point;
}

class _RecentPlace {
  const _RecentPlace({
    required this.title,
    required this.address,
    required this.point,
    this.placeId,
  });

  factory _RecentPlace.fromJson(Map<String, dynamic> json) => _RecentPlace(
    title: (json['title'] ?? json['address'] ?? 'Selected place').toString(),
    address: (json['address'] ?? '').toString(),
    point: LatLng(_readDouble(json['lat']), _readDouble(json['lng'])),
    placeId: json['placeId']?.toString(),
  );

  final String title;
  final String address;
  final LatLng point;
  final String? placeId;

  Map<String, dynamic> toJson() => {
    'title': title,
    'address': address,
    'lat': point.latitude,
    'lng': point.longitude,
    if (placeId != null) 'placeId': placeId,
  };

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
      leading: const Icon(Icons.place_outlined, color: AppTheme.accent),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.mutedText),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.mutedText),
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
    return _SavedPlace(
      label: address.label,
      address: address.address,
      lat: address.lat,
      lng: address.lng,
    );
  }

  SavedAddress toSavedAddress() {
    return SavedAddress(label: label, address: address, lat: lat, lng: lng);
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

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

  static List<_SavedPlace> listFromCache(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => _SavedPlace.fromJson(Map<String, dynamic>.from(item)))
          .where((place) => place.address.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
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
                      backgroundColor: AppTheme.actionBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Find Driver'),
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

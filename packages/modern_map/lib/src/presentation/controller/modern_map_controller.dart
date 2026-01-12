import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/animation.dart' as animation;
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../domain/usecases/load_pois_near.dart';
import '../../domain/usecases/track_user_location.dart';
import 'map_controller.dart' as api;

typedef ModernMapRadiusForZoom = double Function(double zoom);

class ModernMapController extends ChangeNotifier implements api.MapController {
  ModernMapController({
    required GetCurrentLocation getCurrentLocation,
    required TrackUserLocation trackUserLocation,
    required LoadPoisNear loadPoisNear,
    ModernMapRadiusForZoom? radiusForZoom,
    fm.MapController? mapController,
  }) : _getCurrentLocation = getCurrentLocation,
       _trackUserLocation = trackUserLocation,
       _loadPoisNear = loadPoisNear,
       _radiusForZoom = radiusForZoom ?? _defaultRadiusForZoom,
       mapController = mapController ?? fm.MapController();

  final GetCurrentLocation _getCurrentLocation;
  final TrackUserLocation _trackUserLocation;
  final LoadPoisNear _loadPoisNear;
  final ModernMapRadiusForZoom _radiusForZoom;

  final fm.MapController mapController;

  static const double _minZoom = 3;
  static const double _maxZoom = 19;
  static const Duration _poisDebounce = Duration(milliseconds: 450);
  static const double _fallbackZoom = 16;

  GeoPoint? _currentLocation;
  UserLocation? _currentUserLocation;
  StreamSubscription<UserLocation>? _locationSubscription;
  bool _locationLoading = true;

  List<Poi> _pois = const [];
  bool _poisLoading = false;
  String? _poisError;

  Timer? _poisDebounceTimer;
  LatLng? _lastPoisQueryCenter;
  double? _lastPoisQueryZoom;
  double? _lastPoisQueryRadiusMeters;

  bool _isMapReady = false;
  LatLng? _lastCameraCenter;
  double? _lastCameraZoom;
  VoidCallback? _pendingMapAction;

  GeoPoint? _lastAutoScrollLocation;
  Timer? _mapAnimationTimer;
  double _currentRotation = 0.0;
  bool _isAutoScrollEnabled = true;

  GeoPoint? get currentLocation => _currentLocation;
  UserLocation? get userLocation => _currentUserLocation;
  bool get isLocationLoading => _locationLoading;
  List<Poi> get pois => _pois;
  bool get isPoisLoading => _poisLoading;
  String? get poisError => _poisError;

  @override
  api.ModernMapState get state => api.ModernMapState(
    currentLocation: _currentLocation,
    userLocation: _currentUserLocation,
    isLocationLoading: _locationLoading,
    pois: _pois,
    isPoisLoading: _poisLoading,
    poisError: _poisError,
    isAutoScrollEnabled: _isAutoScrollEnabled,
    rotationDegrees: _currentRotation,
  );

  Future<void> refreshPois() async {
    final center = _effectiveCameraCenter();
    if (center == null) return;

    final zoom = _effectiveCameraZoom();
    await _loadPois(
      GeoPoint(center.latitude, center.longitude),
      radiusMeters: _radiusForZoom(zoom),
      queryZoom: zoom,
    );
  }

  @override
  Future<void> init() async {
    await _refreshLocation(loadPois: true);

    _locationSubscription?.cancel();
    _locationSubscription = _trackUserLocation().listen(
      updateUserLocation,
      onError: (e, _) {
        _locationLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _refreshLocation({required bool loadPois}) async {
    _locationLoading = true;
    notifyListeners();

    try {
      final location = await _getCurrentLocation();
      _currentLocation = location;
      _locationLoading = false;
      notifyListeners();

      if (loadPois) {
        await _loadPois(
          location,
          radiusMeters: _radiusForZoom(_effectiveCameraZoom()),
        );
      }
    } catch (e) {
      _locationLoading = false;
      notifyListeners();
    }
  }

  @override
  void updateUserLocation(UserLocation userLocation) {
    _currentUserLocation = userLocation;
    _currentLocation = userLocation.location;
    notifyListeners();
    _handleAutoScroll(userLocation);
  }

  void _handleAutoScroll(UserLocation userLocation) {
    if (!_isAutoScrollEnabled) return;

    final newLocation = userLocation.location;

    if (_lastAutoScrollLocation == null) {
      _lastAutoScrollLocation = newLocation;
      return;
    }

    if (newLocation.latitude < -90 ||
        newLocation.latitude > 90 ||
        newLocation.longitude < -180 ||
        newLocation.longitude > 180) {
      log('Invalid location coordinates received: $newLocation');
      return;
    }

    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(
        _lastAutoScrollLocation!.latitude,
        _lastAutoScrollLocation!.longitude,
      ),
      LatLng(newLocation.latitude, newLocation.longitude),
    );

    double? targetRotation;
    if (userLocation.speed > 1.0) {
      targetRotation = -userLocation.heading;
    }

    if (distance > 50) {
      _animateTo(
        LatLng(newLocation.latitude, newLocation.longitude),
        targetRotation: targetRotation,
      );
      _lastAutoScrollLocation = newLocation;
    } else if (targetRotation != null) {
      final currentRot = mapController.camera.rotation;
      final rotDiff = (currentRot - targetRotation).abs();
      if (rotDiff > 5) {
        _animateTo(
          LatLng(newLocation.latitude, newLocation.longitude),
          targetRotation: targetRotation,
        );
        _lastAutoScrollLocation = newLocation;
      }
    }
  }

  void _animateTo(LatLng target, {double? targetRotation}) {
    _mapAnimationTimer?.cancel();

    final start = mapController.camera.center;
    final startRotation = mapController.camera.rotation;

    final dx = target.latitude - start.latitude;
    final dy = target.longitude - start.longitude;

    final endRotation = targetRotation ?? startRotation;

    const duration = Duration(milliseconds: 900);
    const steps = 60;
    final stepDuration = duration ~/ steps;

    var elapsed = 0;
    _mapAnimationTimer = Timer.periodic(stepDuration, (timer) {
      elapsed += stepDuration.inMilliseconds;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final curvedT = animation.Curves.easeOutCubic.transform(t);

      final lat = start.latitude + dx * curvedT;
      final lng = start.longitude + dy * curvedT;

      var rotDiff = endRotation - startRotation;
      if (rotDiff > 180) rotDiff -= 360;
      if (rotDiff < -180) rotDiff += 360;
      final currentRot = startRotation + rotDiff * curvedT;

      final newCenter = LatLng(lat, lng);
      final currentZoom = mapController.camera.zoom;

      mapController.move(newCenter, currentZoom);
      mapController.rotate(currentRot);

      _lastCameraCenter = newCenter;
      _currentRotation = currentRot;

      onMapCameraChanged(
        centerLat: newCenter.latitude,
        centerLng: newCenter.longitude,
        zoom: currentZoom,
      );

      if (t >= 1.0) {
        timer.cancel();
        _mapAnimationTimer = null;
      }
    });
  }

  @override
  void stopAutoScroll() {
    _mapAnimationTimer?.cancel();
    _mapAnimationTimer = null;
    if (!_isAutoScrollEnabled) return;
    _isAutoScrollEnabled = false;
    notifyListeners();
  }

  @override
  Future<void> moveToCurrentLocation() async {
    _isAutoScrollEnabled = true;
    notifyListeners();

    if (_currentUserLocation != null) {
      final loc = _currentUserLocation!.location;
      _currentLocation = loc;
      final zoom = _effectiveCameraZoom();
      final center = LatLng(loc.latitude, loc.longitude);
      _lastCameraCenter = center;
      _runWhenMapReady(() => mapController.move(center, zoom));
      await _loadPois(
        loc,
        radiusMeters: _radiusForZoom(zoom),
        queryZoom: zoom,
      );
      return;
    }

    await _refreshLocation(loadPois: false);
    final location = _currentLocation;
    if (location == null) return;
    final zoom = _effectiveCameraZoom();
    final center = LatLng(location.latitude, location.longitude);
    _lastCameraCenter = center;
    _runWhenMapReady(() => mapController.move(center, zoom));
    await _loadPois(
      location,
      radiusMeters: _radiusForZoom(zoom),
      queryZoom: zoom,
    );
  }

  @override
  void zoomIn() {
    final center = _effectiveCameraCenter();
    if (center == null) return;
    final nextZoom = (_effectiveCameraZoom() + 1)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _lastCameraCenter = center;
    _lastCameraZoom = nextZoom;
    _runWhenMapReady(() => mapController.move(center, nextZoom));
  }

  @override
  void zoomOut() {
    final center = _effectiveCameraCenter();
    if (center == null) return;
    final nextZoom = (_effectiveCameraZoom() - 1)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _lastCameraCenter = center;
    _lastCameraZoom = nextZoom;
    _runWhenMapReady(() => mapController.move(center, nextZoom));
  }

  void zoomTo(LatLng target, {double delta = 1}) {
    final nextZoom = (_effectiveCameraZoom() + delta)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _lastCameraCenter = target;
    _lastCameraZoom = nextZoom;
    _runWhenMapReady(() => mapController.move(target, nextZoom));
  }

  @override
  void clearPoisError() {
    _poisError = null;
    notifyListeners();
  }

  @override
  void onMapReady({
    required double centerLat,
    required double centerLng,
    required double zoom,
  }) {
    _isMapReady = true;
    final center = LatLng(centerLat, centerLng);
    _lastCameraCenter ??= center;
    _lastCameraZoom ??= zoom;
    final pending = _pendingMapAction;
    _pendingMapAction = null;
    pending?.call();
  }

  void _runWhenMapReady(VoidCallback action) {
    if (_isMapReady) {
      action();
      return;
    }
    _pendingMapAction = action;
  }

  LatLng? _effectiveCameraCenter() {
    final center = _lastCameraCenter;
    if (center != null) return center;
    final loc = _currentLocation;
    if (loc != null) return LatLng(loc.latitude, loc.longitude);
    return null;
  }

  double _effectiveCameraZoom() => _lastCameraZoom ?? _fallbackZoom;

  @override
  void onMapCameraChanged({
    required double centerLat,
    required double centerLng,
    required double zoom,
  }) {
    final center = LatLng(centerLat, centerLng);
    _lastCameraCenter = center;
    _lastCameraZoom = zoom;
    final radiusMeters = _radiusForZoom(zoom);
    if (!_shouldReloadPois(
      center: center,
      zoom: zoom,
      radiusMeters: radiusMeters,
    )) {
      return;
    }

    _poisDebounceTimer?.cancel();
    _poisDebounceTimer = Timer(_poisDebounce, () {
      _loadPois(
        GeoPoint(center.latitude, center.longitude),
        radiusMeters: radiusMeters,
        queryZoom: zoom,
      );
    });
  }

  bool _shouldReloadPois({
    required LatLng center,
    required double zoom,
    required double radiusMeters,
  }) {
    final lastCenter = _lastPoisQueryCenter;
    final lastZoom = _lastPoisQueryZoom;
    final lastRadius = _lastPoisQueryRadiusMeters;
    if (lastCenter == null || lastZoom == null || lastRadius == null) {
      return true;
    }

    final movedMeters = const Distance().as(
      LengthUnit.Meter,
      lastCenter,
      center,
    );

    final zoomChanged = (zoom - lastZoom).abs() >= 0.75;
    final radiusChanged = (radiusMeters - lastRadius).abs() >= 80;
    final movedEnough = movedMeters >= math.max(80, radiusMeters * 0.25);
    return zoomChanged || radiusChanged || movedEnough;
  }

  static double _defaultRadiusForZoom(double zoom) {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    final t = (19 - clamped).clamp(0, 16).toDouble();
    return 250 + t * 120;
  }

  Future<void> _loadPois(
    GeoPoint center, {
    required double radiusMeters,
    double? queryZoom,
  }) async {
    _poisLoading = true;
    _poisError = null;
    notifyListeners();

    try {
      final pois = await _loadPoisNear(
        center: center,
        radiusMeters: radiusMeters,
      );
      _pois = pois;
      _poisLoading = false;
      _lastPoisQueryCenter = LatLng(center.latitude, center.longitude);
      _lastPoisQueryZoom = queryZoom ?? _effectiveCameraZoom();
      _lastPoisQueryRadiusMeters = radiusMeters;
      notifyListeners();
    } catch (e) {
      _poisLoading = false;
      log('_poisError: $e');
      _poisError = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _poisDebounceTimer?.cancel();
    _mapAnimationTimer?.cancel();
    super.dispose();
  }
}

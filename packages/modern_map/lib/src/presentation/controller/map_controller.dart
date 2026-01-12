import 'package:flutter/foundation.dart';

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/user_location.dart';

class ModernMapState {
  const ModernMapState({
    required this.currentLocation,
    required this.userLocation,
    required this.isLocationLoading,
    required this.pois,
    required this.isPoisLoading,
    required this.poisError,
    required this.isAutoScrollEnabled,
    required this.rotationDegrees,
  });

  final GeoPoint? currentLocation;
  final UserLocation? userLocation;
  final bool isLocationLoading;
  final List<Poi> pois;
  final bool isPoisLoading;
  final String? poisError;
  final bool isAutoScrollEnabled;
  final double rotationDegrees;
}

abstract interface class MapController implements Listenable {
  ModernMapState get state;

  Future<void> init();
  void onMapReady({
    required double centerLat,
    required double centerLng,
    required double zoom,
  });
  void onMapCameraChanged({
    required double centerLat,
    required double centerLng,
    required double zoom,
  });

  void stopAutoScroll();
  Future<void> moveToCurrentLocation();
  void zoomIn();
  void zoomOut();

  void clearPoisError();
  void updateUserLocation(UserLocation userLocation);
}

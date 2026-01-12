import '../entities/geo_point.dart';
import '../entities/poi.dart';
import '../entities/user_location.dart';

abstract interface class ModernMapEventListener {
  void onMapReady();
  void onCameraChanged({required GeoPoint center, required double zoom});
  void onUserLocationChanged(UserLocation location);
  void onPoiTapped(Poi poi);
  void onError(Object error);
}

class ModernMapEventListenerAdapter implements ModernMapEventListener {
  const ModernMapEventListenerAdapter({
    this.onMapReadyCallback,
    this.onCameraChangedCallback,
    this.onUserLocationChangedCallback,
    this.onPoiTappedCallback,
    this.onErrorCallback,
  });

  final void Function()? onMapReadyCallback;
  final void Function({required GeoPoint center, required double zoom})?
  onCameraChangedCallback;
  final void Function(UserLocation location)? onUserLocationChangedCallback;
  final void Function(Poi poi)? onPoiTappedCallback;
  final void Function(Object error)? onErrorCallback;

  @override
  void onMapReady() => onMapReadyCallback?.call();

  @override
  void onCameraChanged({required GeoPoint center, required double zoom}) {
    onCameraChangedCallback?.call(center: center, zoom: zoom);
  }

  @override
  void onUserLocationChanged(UserLocation location) {
    onUserLocationChangedCallback?.call(location);
  }

  @override
  void onPoiTapped(Poi poi) => onPoiTappedCallback?.call(poi);

  @override
  void onError(Object error) => onErrorCallback?.call(error);
}


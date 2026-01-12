import '../entities/geo_point.dart';
import '../entities/poi.dart';
import '../entities/user_location.dart';

abstract interface class GeoLocationSource {
  Future<GeoPoint> getCurrentLocation();
  Stream<UserLocation> watchUserLocation();
}

abstract interface class PoiSource {
  Future<List<Poi>> getPoisNear({
    required GeoPoint center,
    required double radiusMeters,
  });
}

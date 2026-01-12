import '../entities/geo_point.dart';

abstract interface class LocationRepository {
  Future<GeoPoint> getCurrentLocation();
}


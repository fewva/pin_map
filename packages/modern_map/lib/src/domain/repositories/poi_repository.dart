import '../entities/geo_point.dart';
import '../entities/poi.dart';

abstract interface class PoiRepository {
  Future<List<Poi>> getPoisNear({
    required GeoPoint center,
    required double radiusMeters,
  });
}


import '../entities/geo_point.dart';
import '../entities/poi.dart';
import '../repositories/poi_repository.dart';

class LoadPoisNear {
  const LoadPoisNear(this._repository);

  final PoiRepository _repository;

  Future<List<Poi>> call({
    required GeoPoint center,
    double radiusMeters = 800,
  }) {
    return _repository.getPoisNear(center: center, radiusMeters: radiusMeters);
  }
}


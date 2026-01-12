import '../entities/geo_point.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocation {
  const GetCurrentLocation(this._repository);

  final LocationRepository _repository;

  Future<GeoPoint> call() => _repository.getCurrentLocation();
}


import '../entities/user_location.dart';
import '../repositories/location_stream_repository.dart';

class TrackUserLocation {
  const TrackUserLocation(this._repository);

  final LocationStreamRepository _repository;

  Stream<UserLocation> call() => _repository.getLocationStream();
}


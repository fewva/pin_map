import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_stream_repository.dart';

class GeolocatorStreamRepository implements LocationStreamRepository {
  @override
  Stream<UserLocation> getLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (position) => UserLocation(
        location: GeoPoint(position.latitude, position.longitude),
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      ),
    );
  }
}


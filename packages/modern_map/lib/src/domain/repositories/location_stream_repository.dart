import '../entities/user_location.dart';

abstract interface class LocationStreamRepository {
  Stream<UserLocation> getLocationStream();
}


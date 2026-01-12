import 'geo_point.dart';

class UserLocation {
  const UserLocation({
    required this.location,
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.timestamp,
  });

  final GeoPoint location;
  final double heading;
  final double speed;
  final double accuracy;
  final DateTime? timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLocation &&
          runtimeType == other.runtimeType &&
          location == other.location &&
          heading == other.heading &&
          speed == other.speed &&
          accuracy == other.accuracy &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      location.hashCode ^
      heading.hashCode ^
      speed.hashCode ^
      accuracy.hashCode ^
      timestamp.hashCode;
}


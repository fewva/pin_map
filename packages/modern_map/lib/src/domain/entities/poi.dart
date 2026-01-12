import 'geo_point.dart';

class Poi {
  const Poi({
    required this.id,
    required this.location,
    required this.name,
    required this.category,
    required this.tags,
  });

  final String id;
  final GeoPoint location;
  final String name;
  final String category;
  final Map<String, String> tags;
}


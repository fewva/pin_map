abstract class PlaceRepository {
  Future<void> addPlace({
    required double lat,
    required double lng,
    required Map<String, String> tags,
  });
}

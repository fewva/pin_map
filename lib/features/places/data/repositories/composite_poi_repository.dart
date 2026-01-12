import 'package:modern_map/modern_map.dart';

class CompositePoiRepository implements PoiRepository {
  final List<PoiRepository> _repositories;

  const CompositePoiRepository(this._repositories);

  @override
  Future<List<Poi>> getPoisNear({
    required GeoPoint center,
    required double radiusMeters,
  }) async {
    final futures = _repositories.map(
      (repo) => repo.getPoisNear(center: center, radiusMeters: radiusMeters),
    );

    final results = await Future.wait(futures);

    return results.expand((element) => element).toList();
  }
}

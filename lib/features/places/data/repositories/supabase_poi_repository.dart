import 'package:modern_map/modern_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePoiRepository implements PoiRepository {
  final SupabaseClient _supabase;

  SupabasePoiRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Poi>> getPoisNear({
    required GeoPoint center,
    required double radiusMeters,
  }) async {
    try {
      final List<dynamic> response = await _supabase.rpc(
        'get_places_nearby',
        params: {
          'lat': center.latitude,
          'lng': center.longitude,
          'radius': radiusMeters.toInt(),
        },
      );

      return response.map((data) {
        final tagsDynamic = data['tags'] ?? {};
        final tags = Map<String, String>.from(tagsDynamic as Map);

        return Poi(
          id: data['id'].toString(),
          location: GeoPoint(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          ),
          name: tags['name'] ?? 'Точка пользователя',
          category: _determineCategory(tags),
          tags: tags,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching Supabase POIs: $e');
      return [];
    }
  }

  String _determineCategory(Map<String, String> tags) {
    if (tags.containsKey('amenity')) return tags['amenity']!;
    if (tags.containsKey('leisure')) return tags['leisure']!;
    if (tags.containsKey('shop')) return tags['shop']!;
    if (tags.containsKey('tourism')) return tags['tourism']!;
    return 'unknown';
  }

  void debugPrint(String message) {
    // ignore: avoid_print
    print(message);
  }
}

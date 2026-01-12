import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/place_repository.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  final SupabaseClient _supabase;

  PlaceRepositoryImpl({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<void> addPlace({
    required double lat,
    required double lng,
    required Map<String, String> tags,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      await _supabase.rpc(
        'add_place',
        params: {
          'p_tags': tags,
          'p_lat': lat,
          'p_lng': lng,
        },
      );
    } catch (e) {
      throw Exception('Ошибка добавления точки: $e');
    }
  }
}

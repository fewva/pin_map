import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/places/data/repositories/place_repository_impl.dart';
import 'features/places/domain/repositories/place_repository.dart';
import 'features/places/presentation/bloc/place_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  if (!sl.isRegistered<SupabaseClient>()) {
    sl.registerLazySingleton(() => Supabase.instance.client);
  }

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(supabase: sl()),
  );
  sl.registerLazySingleton<PlaceRepository>(
    () => PlaceRepositoryImpl(supabase: sl()),
  );

  sl.registerFactory(
    () => AuthBloc(authRepository: sl()),
  );
  sl.registerFactory(
    () => PlaceBloc(placeRepository: sl()),
  );
}

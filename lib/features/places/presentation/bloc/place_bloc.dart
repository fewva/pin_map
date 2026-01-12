import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/place_repository.dart';

part 'place_event.dart';
part 'place_state.dart';

class PlaceBloc extends Bloc<PlaceEvent, PlaceState> {
  final PlaceRepository _placeRepository;

  PlaceBloc({required PlaceRepository placeRepository})
      : _placeRepository = placeRepository,
        super(PlaceState.initial()) {
    on<AddPlaceRequested>(_onAddPlaceRequested);
  }

  Future<void> _onAddPlaceRequested(
    AddPlaceRequested event,
    Emitter<PlaceState> emit,
  ) async {
    emit(state.copyWith(status: PlaceStatus.loading));
    try {
      await _placeRepository.addPlace(
        lat: event.lat,
        lng: event.lng,
        tags: event.tags,
      );
      emit(state.copyWith(status: PlaceStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: PlaceStatus.failure,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }
}

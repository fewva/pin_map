part of 'place_bloc.dart';

enum PlaceStatus { initial, loading, success, failure }

class PlaceState extends Equatable {
  final PlaceStatus status;
  final String? errorMessage;

  const PlaceState({
    this.status = PlaceStatus.initial,
    this.errorMessage,
  });

  factory PlaceState.initial() => const PlaceState();

  PlaceState copyWith({
    PlaceStatus? status,
    String? errorMessage,
  }) {
    return PlaceState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}

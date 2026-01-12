part of 'place_bloc.dart';

abstract class PlaceEvent extends Equatable {
  const PlaceEvent();

  @override
  List<Object> get props => [];
}

class AddPlaceRequested extends PlaceEvent {
  final double lat;
  final double lng;
  final Map<String, String> tags;

  const AddPlaceRequested({
    required this.lat,
    required this.lng,
    required this.tags,
  });

  @override
  List<Object> get props => [lat, lng, tags];
}

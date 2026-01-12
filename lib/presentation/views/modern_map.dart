import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modern_map/modern_map.dart';
import 'package:pin_map/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pin_map/features/places/data/repositories/composite_poi_repository.dart';
import 'package:pin_map/features/places/data/repositories/supabase_poi_repository.dart';
import 'package:pin_map/features/places/presentation/bloc/place_bloc.dart';
import 'package:pin_map/features/places/presentation/widgets/add_place_dialog.dart';
import 'package:pin_map/features/places/presentation/widgets/poi_filter_widget.dart';
import 'package:pin_map/injection_container.dart';

class ModernMapView extends StatefulWidget {
  const ModernMapView({super.key});

  @override
  State<ModernMapView> createState() => _ModernMapViewState();
}

class _ModernMapViewState extends State<ModernMapView> {
  late final ModernMapController _controller;
  final Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();

    final dependencies = ModernMapDependencies(
      locationRepository: GeolocatorLocationRepository(),
      locationStreamRepository: GeolocatorStreamRepository(),
      poiRepository: CompositePoiRepository([
        OverpassPoiRepository(),
        SupabasePoiRepository(),
      ]),
    );

    _controller = ModernMapController(
      getCurrentLocation: GetCurrentLocation(dependencies.locationRepository),
      trackUserLocation: TrackUserLocation(
        dependencies.locationStreamRepository,
      ),
      loadPoisNear: LoadPoisNear(dependencies.poiRepository),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.init();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCategoryToggled(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  bool _poiFilter(Poi poi) {
    if (_selectedCategories.isEmpty) return true;
    if (_selectedCategories.contains('wlan') &&
        poi.tags['internet_access'] == 'wlan') {
      return true;
    }
    if (_selectedCategories.contains('toilets') &&
        poi.tags['amenity'] == 'toilets') {
      return true;
    }
    if (_selectedCategories.contains('atm') && poi.tags['amenity'] == 'atm') {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<PlaceBloc>(),
      child: BlocListener<PlaceBloc, PlaceState>(
        listener: (context, state) {
          if (state.status == PlaceStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Точка успешно добавлена!'),
                backgroundColor: Colors.green,
              ),
            );

            _controller.refreshPois();
          } else if (state.status == PlaceStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Ошибка добавления точки'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Builder(
          builder: (context) {
            return Stack(
              children: [
                ModernMapWidget(
                  controller: _controller,
                  poiFilter: _poiFilter,
                  onMapLongPress: (tapPosition, latLng) async {
                    final authState = context.read<AuthBloc>().state;
                    if (authState.status != AuthStatus.authenticated) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Для добавления точки необходимо войти в систему',
                          ),
                        ),
                      );
                      return;
                    }

                    final tags = await showDialog<Map<String, String>>(
                      context: context,
                      builder: (context) => const AddPlaceDialog(),
                    );

                    if (tags != null) {
                      // ignore: use_build_context_synchronously
                      context.read<PlaceBloc>().add(
                        AddPlaceRequested(
                          lat: latLng.latitude,
                          lng: latLng.longitude,
                          tags: tags,
                        ),
                      );
                    }
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: PoiFilterWidget(
                      selectedCategories: _selectedCategories,
                      onCategoryToggled: _onCategoryToggled,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

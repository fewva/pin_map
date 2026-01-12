import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

import '../../data/repositories/geolocator_location_repository.dart';
import '../../data/repositories/geolocator_stream_repository.dart';
import '../../data/repositories/overpass_poi_repository.dart';
import '../../domain/contracts/map_events.dart';
import '../../domain/contracts/map_lifecycle.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/poi.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/location_stream_repository.dart';
import '../../domain/repositories/poi_repository.dart';
import '../../domain/usecases/get_current_location.dart';
import '../../domain/usecases/load_pois_near.dart';
import '../../domain/usecases/track_user_location.dart';
import '../controller/modern_map_controller.dart';
import 'animated_user_location_layer.dart';
import 'map_core.dart';
import 'poi_details_sheet.dart';
import 'poi_marker.dart';

typedef ModernMapPoiFilter = bool Function(Poi poi);
typedef ModernMapPoiTapCallback = bool Function(BuildContext context, Poi poi);
typedef ModernMapPoiClusterTapCallback =
    bool Function(BuildContext context, List<Poi> pois, LatLng center);
typedef ModernMapPoiDetailsCallback =
    void Function(BuildContext context, Poi poi);
typedef ModernMapPoiMarkerBuilder =
    Widget Function(BuildContext context, Poi poi, VoidCallback onTap);
typedef ModernMapClusterMarkerBuilder =
    Widget Function(BuildContext context, int count, VoidCallback onTap);

class ModernMapDependencies {
  const ModernMapDependencies({
    required this.locationRepository,
    required this.locationStreamRepository,
    required this.poiRepository,
  });

  factory ModernMapDependencies.autonomous() => ModernMapDependencies(
    locationRepository: GeolocatorLocationRepository(),
    locationStreamRepository: GeolocatorStreamRepository(),
    poiRepository: OverpassPoiRepository(),
  );

  final LocationRepository locationRepository;
  final LocationStreamRepository locationStreamRepository;
  final PoiRepository poiRepository;
}

class ModernMapWidget extends StatefulWidget {
  const ModernMapWidget({
    super.key,
    this.controller,
    this.dependencies,
    this.events,
    this.lifecycle,
    this.userAgentPackageName,
    this.initialZoom = 16,
    this.tileUrlTemplate =
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    this.subdomains = const ['a', 'b', 'c'],
    this.interactionFlags = fm.InteractiveFlag.all,
    this.poiMarkerSize = 44,
    this.clusterRadiusPxForZoom,
    this.poiFilter,
    this.onPoiTap,
    this.onPoiClusterTap,
    this.showPoiDetailsOnTap = true,
    this.onShowPoiDetails,
    this.poiMarkerBuilder,
    this.clusterMarkerBuilder,
    this.onMapTap,
    this.onMapLongPress,
    this.onMapEvent,
    this.poiLoadRadiusForZoom,
    this.showControls = true,
    this.controlsBuilder,
  });

  final ModernMapController? controller;
  final ModernMapDependencies? dependencies;
  final ModernMapEventListener? events;
  final ModernMapLifecycleListener? lifecycle;
  final String? userAgentPackageName;
  final double initialZoom;
  final String tileUrlTemplate;
  final List<String> subdomains;
  final int interactionFlags;
  final double poiMarkerSize;
  final double Function(double zoom)? clusterRadiusPxForZoom;
  final ModernMapPoiFilter? poiFilter;
  final ModernMapPoiTapCallback? onPoiTap;
  final ModernMapPoiClusterTapCallback? onPoiClusterTap;
  final bool showPoiDetailsOnTap;
  final ModernMapPoiDetailsCallback? onShowPoiDetails;
  final ModernMapPoiMarkerBuilder? poiMarkerBuilder;
  final ModernMapClusterMarkerBuilder? clusterMarkerBuilder;
  final void Function(fm.TapPosition tapPosition, LatLng latLng)? onMapTap;
  final void Function(fm.TapPosition tapPosition, LatLng latLng)?
  onMapLongPress;
  final void Function(fm.MapEvent event)? onMapEvent;
  final ModernMapRadiusForZoom? poiLoadRadiusForZoom;
  final bool showControls;
  final Widget Function(BuildContext context, ModernMapController controller)?
  controlsBuilder;

  @override
  State<ModernMapWidget> createState() => _ModernMapWidgetState();
}

class _ModernMapWidgetState extends State<ModernMapWidget>
    with WidgetsBindingObserver {
  late final ModernMapController _controller;
  late final bool _ownsController;
  Timer? _uiRefreshThrottle;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    widget.lifecycle?.onInit();

    final externalController = widget.controller;
    if (externalController != null) {
      _ownsController = false;
      _controller = externalController;
    } else {
      _ownsController = true;
      final deps = widget.dependencies ?? ModernMapDependencies.autonomous();
      _controller = ModernMapController(
        getCurrentLocation: GetCurrentLocation(deps.locationRepository),
        trackUserLocation: TrackUserLocation(deps.locationStreamRepository),
        loadPoisNear: LoadPoisNear(deps.poiRepository),
        radiusForZoom: widget.poiLoadRadiusForZoom,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.init();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.lifecycle?.onAppLifecycleStateChanged(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.lifecycle?.onDispose();
    _uiRefreshThrottle?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _scheduleUiRefresh() {
    if (_uiRefreshThrottle?.isActive ?? false) return;
    _uiRefreshThrottle = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      setState(() {});
    });
  }

  double _clusterRadiusPxForZoom(double zoom) {
    final custom = widget.clusterRadiusPxForZoom;
    if (custom != null) return custom(zoom);
    final t = (18 - zoom).clamp(0, 8).toDouble();
    return 44 + t * 4;
  }

  int _cellKey(int x, int y) => (x << 32) ^ (y & 0xffffffff);

  List<_PoiCluster> _clusterPois(List<Poi> pois, fm.MapCamera camera) {
    final radiusPx = _clusterRadiusPxForZoom(camera.zoom);
    final radiusSq = radiusPx * radiusPx;
    final cellSize = radiusPx;

    final grid = <int, List<_PoiCluster>>{};
    final clusters = <_PoiCluster>[];

    for (final poi in pois) {
      final latLng = LatLng(poi.location.latitude, poi.location.longitude);
      final p = camera.projectAtZoom(latLng);
      final pointPx = Offset(p.dx.toDouble(), p.dy.toDouble());
      final cx = (pointPx.dx / cellSize).floor();
      final cy = (pointPx.dy / cellSize).floor();

      _PoiCluster? match;
      for (var dx = -1; dx <= 1 && match == null; dx++) {
        for (var dy = -1; dy <= 1 && match == null; dy++) {
          final key = _cellKey(cx + dx, cy + dy);
          final bucket = grid[key];
          if (bucket == null) continue;
          for (final cluster in bucket) {
            final c = cluster.centerPx;
            final ddx = c.dx - pointPx.dx;
            final ddy = c.dy - pointPx.dy;
            if (ddx * ddx + ddy * ddy <= radiusSq) {
              match = cluster;
              break;
            }
          }
        }
      }

      if (match != null) {
        match.add(poi: poi, latLng: latLng, pointPx: pointPx);
      } else {
        final cluster = _PoiCluster(poi: poi, latLng: latLng, pointPx: pointPx);
        clusters.add(cluster);
        final key = _cellKey(cx, cy);
        (grid[key] ??= <_PoiCluster>[]).add(cluster);
      }
    }

    return clusters;
  }

  List<fm.Marker> _buildPoiMarkers(BuildContext context, fm.MapCamera camera) {
    final filter = widget.poiFilter;
    final sourcePois = filter == null
        ? _controller.pois
        : _controller.pois.where(filter).toList(growable: false);
    final clusters = _clusterPois(sourcePois, camera);
    final markerSize = widget.poiMarkerSize;
    final onShowDetails = widget.onShowPoiDetails ?? PoiDetailsSheet.show;
    return [
      for (final cluster in clusters)
        if (cluster.pois.length == 1)
          () {
            final poi = cluster.pois.first;
            final onTap = () {
              widget.events?.onPoiTapped(poi);
              final handled = widget.onPoiTap?.call(context, poi) ?? false;
              if (!handled && widget.showPoiDetailsOnTap) {
                onShowDetails(context, poi);
              }
            };

            final child =
                widget.poiMarkerBuilder?.call(context, poi, onTap) ??
                PoiMarker(poi: poi, onTap: onTap);

            return fm.Marker(
              point: LatLng(poi.location.latitude, poi.location.longitude),
              width: markerSize,
              height: markerSize,
              rotate: true,
              child: child,
            );
          }()
        else
          () {
            final count = cluster.pois.length;
            final extra = math.min(18.0, math.log(count + 1) * 8).toDouble();
            final size = markerSize + extra;

            final onTap = () {
              final handled =
                  widget.onPoiClusterTap?.call(
                    context,
                    cluster.pois,
                    cluster.centerLatLng,
                  ) ??
                  false;
              if (!handled) {
                _controller.zoomTo(cluster.centerLatLng, delta: 1);
              }
            };

            final child =
                widget.clusterMarkerBuilder?.call(context, count, onTap) ??
                PoiClusterMarker(count: count, onTap: onTap);

            return fm.Marker(
              point: cluster.centerLatLng,
              width: size,
              height: size,
              rotate: true,
              child: child,
            );
          }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLocationLoading ||
            _controller.currentLocation == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final center = _toLatLng(_controller.currentLocation!);

        return Stack(
          children: [
            MapCore(
              mapController: _controller.mapController,
              initialCenter: center,
              initialZoom: widget.initialZoom,
              userAgentPackageName: widget.userAgentPackageName ?? 'modern_map',
              tileUrlTemplate: widget.tileUrlTemplate,
              subdomains: widget.subdomains,
              interactionFlags: widget.interactionFlags,
              onTap: widget.onMapTap,
              onLongPress: widget.onMapLongPress,
              onMapReady: () {
                _controller.onMapReady(
                  centerLat: center.latitude,
                  centerLng: center.longitude,
                  zoom: widget.initialZoom,
                );
                widget.events?.onMapReady();
                _scheduleUiRefresh();
              },
              onMapEvent: (event) {
                widget.onMapEvent?.call(event);
                _scheduleUiRefresh();

                if (event.source == fm.MapEventSource.onDrag ||
                    event.source == fm.MapEventSource.onMultiFinger) {
                  _controller.stopAutoScroll();
                }

                final shouldReloadPois =
                    event is fm.MapEventMoveEnd ||
                    event is fm.MapEventDoubleTapZoomEnd ||
                    event is fm.MapEventFlingAnimationEnd ||
                    event is fm.MapEventRotateEnd;
                if (!shouldReloadPois) return;
                final camera = event.camera;
                widget.events?.onCameraChanged(
                  center: GeoPoint(
                    camera.center.latitude,
                    camera.center.longitude,
                  ),
                  zoom: camera.zoom,
                );
                _controller.onMapCameraChanged(
                  centerLat: camera.center.latitude,
                  centerLng: camera.center.longitude,
                  zoom: camera.zoom,
                );
              },
              children: [
                Builder(
                  builder: (context) {
                    final camera = fm.MapCamera.of(context);
                    final poiMarkers = _buildPoiMarkers(context, camera);
                    return fm.MarkerLayer(markers: poiMarkers);
                  },
                ),
                if (_controller.userLocation != null)
                  AnimatedUserLocationLayer(
                    location: _controller.userLocation!,
                  ),
              ],
            ),
            if (widget.showControls)
              Positioned(
                right: 20,
                bottom: 200,
                child:
                    widget.controlsBuilder?.call(context, _controller) ??
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: 'zoom_in',
                          mini: true,
                          onPressed: _controller.zoomIn,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.add, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton(
                          heroTag: 'zoom_out',
                          mini: true,
                          onPressed: _controller.zoomOut,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.remove, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton(
                          mini: true,
                          heroTag: 'my_location',
                          onPressed: _controller.moveToCurrentLocation,
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
              ),
            if (_controller.isPoisLoading)
              Positioned(
                right: 30,
                bottom: 270,
                child: Container(
                  width: 22,
                  height: 22,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_controller.poisError != null)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(31),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'POI не загрузились. Нажмите кнопку локации, чтобы повторить.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _controller.clearPoisError,
                          icon: const Icon(Icons.close, size: 18),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  LatLng _toLatLng(GeoPoint point) => LatLng(point.latitude, point.longitude);
}

class _PoiCluster {
  _PoiCluster({
    required Poi poi,
    required LatLng latLng,
    required Offset pointPx,
  }) : _pois = [poi],
       _sumLat = latLng.latitude,
       _sumLng = latLng.longitude,
       _sumPxX = pointPx.dx,
       _sumPxY = pointPx.dy;

  final List<Poi> _pois;
  double _sumLat;
  double _sumLng;
  double _sumPxX;
  double _sumPxY;

  List<Poi> get pois => _pois;

  LatLng get centerLatLng =>
      LatLng(_sumLat / _pois.length, _sumLng / _pois.length);

  Offset get centerPx => Offset(
    _sumPxX / _pois.length,
    _sumPxY / _pois.length,
  );

  void add({
    required Poi poi,
    required LatLng latLng,
    required Offset pointPx,
  }) {
    _pois.add(poi);
    _sumLat += latLng.latitude;
    _sumLng += latLng.longitude;
    _sumPxX += pointPx.dx;
    _sumPxY += pointPx.dy;
  }
}

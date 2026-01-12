import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

class MapCore extends StatelessWidget {
  const MapCore({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.children,
    this.onMapReady,
    this.onMapEvent,
    this.onTap,
    this.onLongPress,
    this.tileUrlTemplate =
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    this.subdomains = const ['a', 'b', 'c'],
    this.userAgentPackageName = 'modern_map',
    this.interactionFlags = fm.InteractiveFlag.all,
  });

  final fm.MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Widget> children;
  final VoidCallback? onMapReady;
  final void Function(fm.MapEvent event)? onMapEvent;
  final void Function(fm.TapPosition tapPosition, LatLng latLng)? onTap;
  final void Function(fm.TapPosition tapPosition, LatLng latLng)? onLongPress;
  final String tileUrlTemplate;
  final List<String> subdomains;
  final String userAgentPackageName;
  final int interactionFlags;

  @override
  Widget build(BuildContext context) {
    return fm.FlutterMap(
      mapController: mapController,
      options: fm.MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onMapReady: onMapReady,
        onMapEvent: onMapEvent,
        onTap: onTap,
        onLongPress: onLongPress,
        interactionOptions: fm.InteractionOptions(flags: interactionFlags),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: tileUrlTemplate,
          subdomains: subdomains,
          userAgentPackageName: userAgentPackageName,
        ),
        ...children,
      ],
    );
  }
}

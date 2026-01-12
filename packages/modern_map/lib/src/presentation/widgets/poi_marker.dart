import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/poi.dart';

class PoiMarker extends StatelessWidget {
  const PoiMarker({super.key, required this.poi, required this.onTap});

  final Poi poi;
  final VoidCallback onTap;

  LatLng get point => LatLng(poi.location.latitude, poi.location.longitude);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(_iconForPoi(poi), color: Colors.black87, size: 20),
          ),
        ),
      ),
    );
  }

  IconData _iconForPoi(Poi poi) {
    final amenity = poi.tags['amenity'];
    if (amenity == 'toilets') {
      return Icons.wc;
    }
    if (amenity == 'atm' || amenity == 'bank') {
      return Icons.account_balance;
    }
    if (poi.tags.containsKey('internet_access')) {
      return Icons.wifi;
    }
    return Icons.place;
  }
}

class PoiClusterMarker extends StatelessWidget {
  const PoiClusterMarker({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


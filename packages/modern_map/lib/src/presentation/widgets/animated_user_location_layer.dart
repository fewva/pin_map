import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/user_location.dart';

class AnimatedUserLocationLayer extends StatefulWidget {
  const AnimatedUserLocationLayer({
    super.key,
    required this.location,
    this.animationDuration = const Duration(milliseconds: 2000),
  });

  final UserLocation location;
  final Duration animationDuration;

  @override
  State<AnimatedUserLocationLayer> createState() =>
      _AnimatedUserLocationLayerState();
}

class _AnimatedUserLocationLayerState extends State<AnimatedUserLocationLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late LatLng _prevPosition;
  late LatLng _targetPosition;
  late double _prevHeading;
  late double _targetHeading;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    final latLng = LatLng(
      widget.location.location.latitude,
      widget.location.location.longitude,
    );
    _prevPosition = latLng;
    _targetPosition = latLng;
    _prevHeading = widget.location.heading;
    _targetHeading = widget.location.heading;
  }

  @override
  void didUpdateWidget(covariant AnimatedUserLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.location != oldWidget.location) {
      final newLatLng = LatLng(
        widget.location.location.latitude,
        widget.location.location.longitude,
      );
      final newHeading = widget.location.heading;

      final currentPos = _evaluatePosition(_controller.value);
      final currentHeading = _evaluateHeading(_controller.value);

      setState(() {
        _prevPosition = currentPos;
        _targetPosition = newLatLng;
        _prevHeading = currentHeading;
        _targetHeading = newHeading;
      });

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _evaluatePosition(double t) {
    if (t == 0.0) return _prevPosition;
    if (t == 1.0) return _targetPosition;
    return LatLng(
      lerpDouble(_prevPosition.latitude, _targetPosition.latitude, t)!,
      lerpDouble(_prevPosition.longitude, _targetPosition.longitude, t)!,
    );
  }

  double _evaluateHeading(double t) {
    if (t == 0.0) return _prevHeading;
    if (t == 1.0) return _targetHeading;

    var delta = _targetHeading - _prevHeading;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    return (_prevHeading + delta * t) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = _evaluatePosition(_controller.value);
        final heading = _evaluateHeading(_controller.value);

        return MarkerLayer(
          markers: [
            Marker(
              point: position,
              width: 60,
              height: 60,
              child: Transform.rotate(
                angle: heading * (pi / 180),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.blue,
                  size: 44,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

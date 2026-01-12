import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/poi.dart';
import '../../domain/repositories/poi_repository.dart';

class OverpassPoiRepository implements PoiRepository {
  OverpassPoiRepository({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint =
          endpoint ?? Uri.parse('https://overpass-api.de/api/interpreter');

  final http.Client _client;
  final Uri _endpoint;

  static final List<Uri> _fallbackEndpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
    Uri.parse('https://overpass.nchc.org.tw/api/interpreter'),
  ];

  Future<http.Response> _postWithRetry(String query) async {
    final endpoints = [_endpoint, ..._fallbackEndpoints]
      ..removeWhere((e) => e == _endpoint);

    var lastError = Object();
    for (final endpoint in endpoints) {
      try {
        final response = await _client.post(
          endpoint,
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'data': query},
        );
        if (response.statusCode == 200) return response;
        lastError = Exception('Overpass error: ${response.statusCode}');
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 200 + math.Random().nextInt(300)),
      );
    }
    throw lastError;
  }

  bool _isPublicToilet(Map<String, String> tags) {
    if (tags['amenity'] != 'toilets') return false;
    final access = (tags['access'] ?? tags['toilets:access'] ?? '').toLowerCase();
    if (access.isEmpty) return true;
    return access == 'public' || access == 'yes' || access == 'permissive';
  }

  bool _isAtm(Map<String, String> tags) {
    if (tags['amenity'] == 'atm') return true;
    if (tags['amenity'] == 'bank') {
      final atm = (tags['atm'] ?? '').toLowerCase();
      return atm == 'yes' || atm == 'only';
    }
    return false;
  }

  bool _isWifiPoint(Map<String, String> tags) {
    final internetAccess = (tags['internet_access'] ?? '').toLowerCase();
    if (internetAccess.isEmpty) return false;
    if (internetAccess == 'no' || internetAccess == 'none') return false;
    return internetAccess == 'wlan' ||
        internetAccess == 'wifi' ||
        internetAccess == 'yes';
  }

  String _fallbackName(Map<String, String> tags) {
    if (_isPublicToilet(tags)) return 'Туалет';
    if (_isAtm(tags)) return 'Банкомат';
    if (_isWifiPoint(tags)) return 'Wi‑Fi';
    return 'POI';
  }

  @override
  Future<List<Poi>> getPoisNear({
    required GeoPoint center,
    required double radiusMeters,
  }) async {
    final radius = radiusMeters.round();
    final query =
        '''
[out:json][timeout:25];
(
  nwr(around:$radius,${center.latitude},${center.longitude})["amenity"="toilets"]["access"~"^(public|yes|permissive)\$"];
  nwr(around:$radius,${center.latitude},${center.longitude})["amenity"="toilets"]["toilets:access"~"^(public|yes|permissive)\$"];
  nwr(around:$radius,${center.latitude},${center.longitude})["amenity"="atm"];
  nwr(around:$radius,${center.latitude},${center.longitude})["amenity"="bank"]["atm"~"^(yes|only)\$"];
  nwr(around:$radius,${center.latitude},${center.longitude})["internet_access"~"^(wlan|wifi|yes)\$"];
);
out center;
''';

    final response = await _postWithRetry(query);

    if (response.statusCode != 200) {
      throw Exception('Overpass error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response');
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      throw Exception('Unexpected response');
    }

    final pois = <Poi>[];
    final seenIds = <String>{};
    for (final element in elements) {
      if (element is! Map) continue;

      final type = element['type']?.toString() ?? 'unknown';
      final id = '$type:${element['id']}';
      if (!seenIds.add(id)) continue;

      final tagsDynamic = element['tags'];
      final tags = <String, String>{};
      if (tagsDynamic is Map) {
        for (final entry in tagsDynamic.entries) {
          final k = entry.key;
          final v = entry.value;
          if (k is String && v != null) {
            tags[k] = v.toString();
          }
        }
      }

      final isAllowed =
          _isPublicToilet(tags) || _isAtm(tags) || _isWifiPoint(tags);
      if (!isAllowed) continue;

      double? lat;
      double? lon;
      if (type == 'node') {
        final latNum = element['lat'];
        final lonNum = element['lon'];
        if (latNum is num) lat = latNum.toDouble();
        if (lonNum is num) lon = lonNum.toDouble();
      } else {
        final centerDynamic = element['center'];
        if (centerDynamic is Map) {
          final latNum = centerDynamic['lat'];
          final lonNum = centerDynamic['lon'];
          if (latNum is num) lat = latNum.toDouble();
          if (lonNum is num) lon = lonNum.toDouble();
        }
      }
      if (lat == null || lon == null) continue;

      final category = _isPublicToilet(tags)
          ? 'toilets'
          : _isAtm(tags)
          ? 'atm'
          : _isWifiPoint(tags)
          ? 'wifi'
          : 'poi';

      final name = tags['name']?.trim();

      pois.add(
        Poi(
          id: id,
          location: GeoPoint(lat, lon),
          name: (name == null || name.isEmpty) ? _fallbackName(tags) : name,
          category: category,
          tags: tags,
        ),
      );
    }

    return pois;
  }
}


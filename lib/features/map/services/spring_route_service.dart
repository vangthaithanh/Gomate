import 'dart:convert';
import 'dart:io';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/config/api_config.dart';
import '../models/map_route.dart';

/// Flutter -> Spring Boot -> RoutingProvider -> MapboxRoutingProvider.
///
/// Flutter KHÔNG gọi Mapbox Directions trực tiếp.
class SpringRouteService {
  const SpringRouteService();

  List<String> _baseUrls() {
    return ApiConfig.candidateBaseUrls;
  }

  Future<GoMateMapRoute> calculate({required List<String> placeIds}) async {
    if (placeIds.length < 2) {
      throw ArgumentError('Route cần ít nhất 2 GoMate placeId.');
    }

    return _postRoute(
      path: '/routes/compute',
      body: {'placeIds': placeIds},
      fallbackOrderedPlaceIds: placeIds,
    );
  }

  /// Route business contract:
  /// Default: Flutter gửi GPS runtime coordinate + destination places.id.
  /// Option đổi điểm đầu: Flutter gửi origin places.id + destination places.id.
  Future<GoMateMapRoute> calculateDirections({
    String? originPlaceId,
    double? originLatitude,
    double? originLongitude,
    required String destinationPlaceId,
  }) {
    final body = <String, dynamic>{'destinationPlaceId': destinationPlaceId};

    if (originPlaceId != null) {
      body['originPlaceId'] = originPlaceId;
    } else {
      body['originLatitude'] = originLatitude;
      body['originLongitude'] = originLongitude;
    }

    return _postRoute(
      path: '/routes/directions',
      body: body,
      fallbackOrderedPlaceIds: [
        originPlaceId ?? 'current-location',
        destinationPlaceId,
      ],
    );
  }

  Future<GoMateMapRoute> _postRoute({
    required String path,
    required Map<String, dynamic> body,
    required List<String> fallbackOrderedPlaceIds,
  }) async {
    Object? lastError;

    for (final baseUrl in _baseUrls()) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      try {
        final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.write(jsonEncode(body));

        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );

        final responseBody = await utf8.decoder.bind(response).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Route API HTTP ${response.statusCode}: $responseBody',
            uri: uri,
          );
        }

        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return _parseRoute(json, fallbackOrderedPlaceIds);
      } catch (e) {
        lastError = e;
      } finally {
        client.close(force: true);
      }
    }

    throw StateError('Không gọi được Route API: $lastError');
  }

  GoMateMapRoute _parseRoute(
    Map<String, dynamic> json,
    List<String> fallbackOrderedPlaceIds,
  ) {
    final rawGeometry = json['geometry'] as List<dynamic>? ?? const <dynamic>[];

    final geometry = rawGeometry.map((raw) {
      final pair = raw as List<dynamic>;
      return Position((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
    }).toList();

    final ordered =
        (json['orderedPlaceIds'] as List<dynamic>? ?? fallbackOrderedPlaceIds)
            .map((e) => e.toString())
            .toList();

    return GoMateMapRoute(
      routeId: json['routeId']?.toString() ?? 'route',
      geometry: geometry,
      distanceKm: ((json['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      durationMinutes:
          (((json['durationSeconds'] as num?)?.toDouble() ?? 0) / 60).round(),
      orderedPlaceIds: ordered,
    );
  }
}

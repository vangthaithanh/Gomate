import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../models/place_models.dart';

class PlaceApi {
  final http.Client _client;
  final List<String>? _baseUrls;

  PlaceApi({http.Client? client, List<String>? baseUrls})
    : _client = client ?? http.Client(),
      _baseUrls = baseUrls;

  Future<List<PlaceSummary>> listPlaces() async {
    final json = await _get('/places');
    return _parseSummaryList(json);
  }

  Future<List<PlaceSummary>> searchPlaces(String query) async {
    final q = query.trim();
    final json = await _get(
      '/places/search',
      queryParameters: q.isEmpty ? const {} : {'q': q},
    );
    return _parseSummaryList(json);
  }

  Future<PlaceDetail> getPlace(int id) async {
    final json = await _get('/places/$id');
    final data = _unwrapData(json);
    if (data is! Map) {
      throw const ApiException(
        0,
        'INVALID_RESPONSE',
        'Place detail API trả dữ liệu không hợp lệ.',
      );
    }
    return PlaceDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Object?> _get(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    final bases = _baseUrls ?? ApiConfig.candidateBaseUrls;
    Object? lastError;

    for (final base in bases) {
      final uri = _uri(base, path, queryParameters);
      if (kReleaseMode && uri.scheme != 'https') {
        throw const ApiException(
          0,
          'CONFIG_ERROR',
          'Bản phát hành yêu cầu kết nối HTTPS.',
        );
      }

      try {
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));

        return _decode(response);
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } on FormatException catch (error) {
        throw ApiException(
          0,
          'INVALID_RESPONSE',
          'Place API trả dữ liệu không đúng định dạng: ${error.message}',
        );
      }
    }

    throw ApiException(
      0,
      'NETWORK_ERROR',
      'Không kết nối được Place API. Kiểm tra backend GoMate và cổng 8081.'
          '${lastError == null ? '' : '\n$lastError'}',
    );
  }

  Uri _uri(String base, String path, Map<String, String> queryParameters) {
    final baseUri = Uri.parse(base.replaceAll(RegExp(r'/+$'), ''));
    final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    return baseUri.replace(
      path: '$basePath$path',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Object? _decode(http.Response response) {
    Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        response.statusCode,
        'INVALID_RESPONSE',
        'Máy chủ trả dữ liệu Place không hợp lệ.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded is Map ? decoded['error'] : null;
    final code = error is Map
        ? error['code']?.toString()
        : decoded is Map
        ? decoded['code']?.toString()
        : null;
    final message = error is Map
        ? error['message']?.toString()
        : decoded is Map
        ? decoded['message']?.toString()
        : null;

    throw ApiException(
      response.statusCode,
      code ?? 'HTTP_ERROR',
      message ?? 'Không tải được dữ liệu địa điểm.',
    );
  }

  List<PlaceSummary> _parseSummaryList(Object? json) {
    final data = _unwrapData(json);
    if (data is! List) {
      throw const ApiException(
        0,
        'INVALID_RESPONSE',
        'Place list/search API phải trả danh sách địa điểm.',
      );
    }

    return data
        .whereType<Map>()
        .map((item) => PlaceSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Object? _unwrapData(Object? json) {
    if (json is Map && json.containsKey('data')) {
      return json['data'];
    }
    return json;
  }
}

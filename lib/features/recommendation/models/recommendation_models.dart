class RecommendationResponse {
  final String modelVersion;
  final bool coldStart;
  final List<String> optionCodes;
  final String? scoringMode;
  final List<RecommendedPlace> items;
  final List<String> warnings;

  const RecommendationResponse({
    required this.modelVersion,
    required this.coldStart,
    required this.optionCodes,
    required this.scoringMode,
    required this.items,
    required this.warnings,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawOptions = json['optionCodes'];
    final rawWarnings = json['warnings'];

    return RecommendationResponse(
      modelVersion: _stringOrDefault(json['modelVersion'], 'v11'),
      coldStart: _boolOrDefault(json['coldStart'], true),
      optionCodes: _stringList(rawOptions),
      scoringMode: _stringOrNull(json['scoringMode']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      RecommendedPlace.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <RecommendedPlace>[],
      warnings: _stringList(rawWarnings),
    );
  }
}

class RecommendedPlace {
  final int placeId;
  final String? externalId;
  final String name;
  final String? description;
  final String? category;
  final String? categoryName;
  final String? province;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final int saveCount;
  final String? thumbnailUrl;
  final String? destinationKey;
  final double score;
  final String? reason;
  final String? modelSource;

  const RecommendedPlace({
    required this.placeId,
    required this.externalId,
    required this.name,
    required this.description,
    required this.category,
    required this.categoryName,
    required this.province,
    required this.district,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.saveCount,
    required this.thumbnailUrl,
    required this.destinationKey,
    required this.score,
    required this.reason,
    required this.modelSource,
  });

  factory RecommendedPlace.fromJson(Map<String, dynamic> json) {
    return RecommendedPlace(
      placeId: _intOrDefault(json['placeId'] ?? json['id'], 0),
      externalId: _stringOrNull(json['externalId']),
      name: _stringOrDefault(json['name'], 'Địa điểm gợi ý'),
      description: _stringOrNull(json['description']),
      category: _stringOrNull(json['category']),
      categoryName: _stringOrNull(json['categoryName']),
      province: _stringOrNull(json['province']),
      district: _stringOrNull(json['district']),
      address: _stringOrNull(json['address']),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      rating: _doubleOrDefault(json['avgRating'] ?? json['rating'], 0),
      reviewCount: _intOrDefault(json['reviewCount'], 0),
      saveCount: _intOrDefault(json['saveCount'], 0),
      thumbnailUrl: _stringOrNull(json['thumbnailUrl'] ?? json['thumbnail']),
      destinationKey: _stringOrNull(json['destinationKey']),
      score: _doubleOrDefault(json['score'], 0),
      reason: _stringOrNull(json['reason']),
      modelSource: _stringOrNull(json['modelSource']),
    );
  }

  String get locationText {
    final parts = [district, province]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) return parts.join(', ');
    return address ?? 'Địa điểm phù hợp với sở thích của bạn';
  }

  String get displayCategory {
    return categoryName ?? category ?? 'Địa điểm';
  }

  String get displayReason {
    return reason ??
        description ??
        'Được đề xuất từ 3 nhóm câu hỏi bạn đã chọn lúc bắt đầu.';
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _stringOrDefault(Object? value, String fallback) {
  return _stringOrNull(value) ?? fallback;
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _boolOrDefault(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

int _intOrDefault(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleOrDefault(Object? value, double fallback) {
  return _doubleOrNull(value) ?? fallback;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

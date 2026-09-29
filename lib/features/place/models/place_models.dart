class PlaceSummary {
  final int placeId;
  final String name;
  final String category;
  final String categoryName;
  final double latitude;
  final double longitude;
  final String province;
  final String? district;
  final String? address;
  final String? thumbnailUrl;

  const PlaceSummary({
    required this.placeId,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.latitude,
    required this.longitude,
    required this.province,
    this.district,
    this.address,
    this.thumbnailUrl,
  });

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    return PlaceSummary(
      placeId: _requiredInt(json, 'placeId'),
      name: _requiredString(json, 'name'),
      category: _requiredString(json, 'category'),
      categoryName: _requiredString(json, 'categoryName'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      province: _requiredString(json, 'province'),
      district: _stringOrNull(json['district']),
      address: _stringOrNull(json['address']),
      thumbnailUrl: _stringOrNull(json['thumbnailUrl']),
    );
  }
}

class PlaceCategory {
  final int id;
  final String code;
  final String name;

  const PlaceCategory({
    required this.id,
    required this.code,
    required this.name,
  });

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: _requiredInt(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
    );
  }
}

class PlaceMedia {
  final int id;
  final String mediaType;
  final String url;
  final String? caption;
  final int sortOrder;
  final DateTime? createdAt;

  const PlaceMedia({
    required this.id,
    required this.mediaType,
    required this.url,
    this.caption,
    required this.sortOrder,
    this.createdAt,
  });

  factory PlaceMedia.fromJson(Map<String, dynamic> json) {
    return PlaceMedia(
      id: _requiredInt(json, 'id'),
      mediaType: _requiredString(json, 'mediaType'),
      url: _requiredString(json, 'url'),
      caption: _stringOrNull(json['caption']),
      sortOrder: _intOrDefault(json['sortOrder'], 0),
      createdAt: _dateTimeOrNull(json['createdAt']),
    );
  }
}

class PlaceDetail {
  final int id;
  final String name;
  final PlaceCategory category;
  final String? description;
  final String province;
  final String? district;
  final String? address;
  final double latitude;
  final double longitude;
  final String? openingHours;
  final int? priceLevel;
  final double rating;
  final int reviewCount;
  final int saveCount;
  final String sourceType;
  final String status;
  final List<PlaceMedia> media;

  const PlaceDetail({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.province,
    this.district,
    this.address,
    required this.latitude,
    required this.longitude,
    this.openingHours,
    this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.saveCount,
    required this.sourceType,
    required this.status,
    required this.media,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final rawMedia = json['media'];
    return PlaceDetail(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      category: PlaceCategory.fromJson(_requiredMap(categoryJson, 'category')),
      description: _stringOrNull(json['description']),
      province: _requiredString(json, 'province'),
      district: _stringOrNull(json['district']),
      address: _stringOrNull(json['address']),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      openingHours: _stringOrNull(json['openingHours']),
      priceLevel: _intOrNull(json['priceLevel']),
      rating: _doubleOrDefault(json['avgRating'], 0),
      reviewCount: _intOrDefault(json['reviewCount'], 0),
      saveCount: _intOrDefault(json['saveCount'], 0),
      sourceType: _requiredString(json, 'sourceType'),
      status: _requiredString(json, 'status'),
      media: rawMedia is List
          ? rawMedia
                .whereType<Map>()
                .map(
                  (item) =>
                      PlaceMedia.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <PlaceMedia>[],
    );
  }
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Place API field "$field" must be an object.');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = _stringOrNull(json[field]);
  if (value == null) {
    throw FormatException('Place API field "$field" is missing.');
  }
  return value;
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = _intOrNull(json[field]);
  if (value == null) {
    throw FormatException('Place API field "$field" must be an integer.');
  }
  return value;
}

int _intOrDefault(Object? value, int fallback) => _intOrNull(value) ?? fallback;

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = _doubleOrNull(json[field]);
  if (value == null) {
    throw FormatException('Place API field "$field" must be a number.');
  }
  return value;
}

double _doubleOrDefault(Object? value, double fallback) =>
    _doubleOrNull(value) ?? fallback;

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTimeOrNull(Object? value) {
  final text = _stringOrNull(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

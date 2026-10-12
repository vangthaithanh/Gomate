import '../../../core/services/auth_service.dart';
import '../../messages/models/message_models.dart';
import '../models/trip_ui_models.dart';

class TripCreateDraft {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> selectedMemberIds;

  const TripCreateDraft({
    required this.title,
    required this.startDate,
    required this.endDate,
    this.selectedMemberIds = const <String>[],
  });
}

class RealTripRepository {
  RealTripRepository._();

  static final RealTripRepository instance = RealTripRepository._();

  Future<List<TripUi>> list() async {
    final response = await AuthService.instance.requestJson('GET', '/trips');
    return _asList(response).map(_fromSummary).toList(growable: false);
  }

  Future<TripUi> detail(String tripId) async {
    final response = await AuthService.instance.request(
      'GET',
      '/trips/$tripId',
    );
    return _fromDetail(response);
  }

  Future<TripUi?> pinned() async {
    final response = await AuthService.instance.requestJson(
      'GET',
      '/trips/pinned',
    );
    if (response is Map<String, dynamic> && response['trip'] is Map) {
      return _fromDetail(response['trip']);
    }
    return null;
  }

  Future<TripUi> create(TripCreateDraft draft) async {
    final response = await AuthService.instance.request(
      'POST',
      '/trips',
      body: {
        'title': draft.title.trim(),
        'selectedMemberIds': draft.selectedMemberIds,
        'startDate': _date(draft.startDate),
        'endDate': _date(draft.endDate),
        'timezone': 'Asia/Ho_Chi_Minh',
      },
    );
    return _fromDetail(response);
  }

  Future<List<MessageContact>> searchMemberCandidates(String query) async {
    final q = query.trim();
    final uri = Uri(
      path: '/users/search',
      queryParameters: <String, String>{'q': q, 'page': '0', 'size': '20'},
    );
    final response = await AuthService.instance.request('GET', uri.toString());
    return _asList(
      response['items'],
    ).map(_contact).where((item) => item.id.isNotEmpty).toList(growable: false);
  }

  Future<TripUi> update(
    String tripId, {
    String? title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title.trim();
    if (startDate != null) body['startDate'] = _date(startDate);
    if (endDate != null) body['endDate'] = _date(endDate);
    final response = await AuthService.instance.request(
      'PATCH',
      '/trips/$tripId',
      body: body,
    );
    return _fromDetail(response);
  }

  Future<void> delete(String tripId) async {
    await AuthService.instance.request('DELETE', '/trips/$tripId');
  }

  Future<TripUi> pin(String tripId) async {
    final response = await AuthService.instance.request(
      'POST',
      '/trips/$tripId/pin',
    );
    return _fromDetail(response);
  }

  Future<void> unpin(String tripId) async {
    await AuthService.instance.request('DELETE', '/trips/$tripId/pin');
  }

  Future<void> publishLocation(
    String tripId, {
    required double latitude,
    required double longitude,
    double? accuracyM,
  }) async {
    await AuthService.instance.request(
      'PUT',
      '/trips/$tripId/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyM != null) 'accuracyM': accuracyM,
      },
    );
  }

  Future<TripUi> addMembers(
    String tripId,
    Iterable<String> selectedMemberIds,
  ) async {
    final ids = selectedMemberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final response = await AuthService.instance.request(
      'POST',
      '/trips/$tripId/members',
      body: {'selectedMemberIds': ids},
    );
    return _fromDetail(response);
  }

  Future<TripUi> addStop(
    String tripId, {
    required String placeId,
    required int dayNo,
    required DateTime? tripStartDate,
    String? startTime,
    String? endTime,
  }) async {
    final numericPlaceId = int.tryParse(placeId.trim());
    if (numericPlaceId == null) {
      throw ArgumentError('Place ID không hợp lệ.');
    }

    final body = <String, dynamic>{'placeId': numericPlaceId, 'dayNo': dayNo};

    final start = _plannedStartAt(tripStartDate, dayNo, startTime);
    final end = _plannedEndAt(tripStartDate, dayNo, endTime);
    if (start != null) body['plannedStartAt'] = start;
    if (start != null && end != null) body['plannedEndAt'] = end;

    final response = await AuthService.instance.request(
      'POST',
      '/trips/$tripId/stops',
      body: body,
    );
    return _fromDetail(response);
  }

  Future<TripUi> updateStop(
    String tripId,
    String stopId, {
    String? placeId,
    int? dayNo,
    DateTime? tripStartDate,
    String? startTime,
    String? endTime,
  }) async {
    final body = <String, dynamic>{};

    final trimmedPlaceId = placeId?.trim();
    if (trimmedPlaceId != null && trimmedPlaceId.isNotEmpty) {
      final numericPlaceId = int.tryParse(trimmedPlaceId);
      if (numericPlaceId == null) {
        throw ArgumentError('Place ID không hợp lệ.');
      }
      body['placeId'] = numericPlaceId;
    }

    if (dayNo != null) body['dayNo'] = dayNo;

    final start = _plannedStartAt(tripStartDate, dayNo ?? 1, startTime);
    final end = _plannedEndAt(tripStartDate, dayNo ?? 1, endTime);
    if (start == null) {
      body['clearTime'] = true;
    } else {
      body['plannedStartAt'] = start;
      if (end != null) body['plannedEndAt'] = end;
    }

    final response = await AuthService.instance.request(
      'PATCH',
      '/trips/$tripId/stops/$stopId',
      body: body,
    );
    return _fromDetail(response);
  }

  Future<TripUi> deleteStop(String tripId, String stopId) async {
    await AuthService.instance.request(
      'DELETE',
      '/trips/$tripId/stops/$stopId',
    );
    return detail(tripId);
  }

  Future<TripUi> reorderStops(String tripId, List<TripPlaceUi> places) async {
    final response = await AuthService.instance.request(
      'PATCH',
      '/trips/$tripId/stops/reorder',
      body: {'stops': _stopOrderPayload(places)},
    );
    return _fromDetail(response);
  }

  Future<TripUi> optimizeStops(String tripId, {int? dayNo}) async {
    final body = <String, dynamic>{};
    if (dayNo != null) body['dayNo'] = dayNo;
    final response = await AuthService.instance.request(
      'POST',
      '/trips/$tripId/stops/optimize',
      body: body,
    );
    return _fromDetail(response);
  }

  TripUi _fromSummary(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final start = _parseDate(json['startDate']);
    final end = _parseDate(json['endDate']);
    final type = _text(json['tripType']);
    return TripUi(
      id: _text(json['id']),
      title: _text(json['title'], fallback: 'Lịch trình'),
      days: _days(start, end),
      destination: _destination(json),
      isActive: _bool(json['pinned']),
      isGroup: type == 'GROUP',
      currentUserRole: type == 'GROUP'
          ? TripAccessRole.leader
          : TripAccessRole.personal,
      startDate: start,
      endDate: end,
      members: const <TripMemberUi>[],
      conversationId: _nullableText(json['linkedConversationId']),
      places: _placeholderStops(_int(json['stopCount'])),
    );
  }

  TripUi _fromDetail(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final start = _parseDate(json['startDate']);
    final end = _parseDate(json['endDate']);
    final type = _text(json['tripType']);
    final members = _asList(json['members']).map(_member).toList();
    return TripUi(
      id: _text(json['id']),
      title: _text(json['title'], fallback: 'Lịch trình'),
      days: _days(start, end),
      destination: _destination(json),
      isActive: _bool(json['pinned']),
      isGroup: type == 'GROUP',
      currentUserRole: _roleForCurrentUser(members, type),
      startDate: start,
      endDate: end,
      members: members,
      conversationId: _nullableText(json['linkedConversationId']),
      places: _asList(json['stops']).map(_stop).toList(growable: false),
    );
  }

  MessageContact _contact(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final nickname = _text(json['nickname']);
    final displayName = _text(json['displayName'], fallback: nickname);
    final city = _text(json['city']);
    final bio = _text(json['bio']);
    final subtitle = city.isNotEmpty
        ? city
        : (bio.isNotEmpty
              ? bio
              : (nickname.isEmpty ? 'Người dùng GoMate' : '@$nickname'));
    return MessageContact(
      id: _text(json['userId']),
      name: displayName.isEmpty ? nickname : displayName,
      subtitle: subtitle,
      avatarAsset: _nullableText(json['avatarUrl']),
    );
  }

  TripMemberUi _member(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final id = _text(json['userId']);
    final role = _text(json['role']) == 'LEADER'
        ? TripAccessRole.leader
        : TripAccessRole.member;
    final currentUserId = _currentUserId;
    return TripMemberUi(
      id: id,
      name: id == currentUserId
          ? _currentUserName
          : _text(json['displayName'], fallback: 'Thành viên'),
      avatarAsset: _text(json['avatarUrl']),
      role: role,
      lastSeen: '',
    );
  }

  TripPlaceUi _stop(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return TripPlaceUi(
      id: _text(json['id']),
      placeId: _idText(json['placeId']),
      name: _text(json['name'], fallback: 'Địa điểm'),
      day: _int(json['dayNo'], fallback: 1),
      startTime: _timeFromStart(json['plannedStartAt']),
      endTime: _timeFromStart(json['plannedEndAt']),
      hasCompleteInterval: _bool(json['hasCompleteInterval']),
      imageUrl: _nullableText(json['thumbnailUrl']),
    );
  }

  static List<TripPlaceUi> _placeholderStops(int count) {
    if (count <= 0) return const <TripPlaceUi>[];
    return List<TripPlaceUi>.generate(
      count,
      (index) => TripPlaceUi(
        id: 'summary-stop-$index',
        placeId: '',
        name: 'Địa điểm ${index + 1}',
        day: 1,
      ),
      growable: false,
    );
  }

  static List<Map<String, dynamic>> _stopOrderPayload(
    List<TripPlaceUi> places,
  ) {
    final dayCounters = <int, int>{};
    return [
      for (final place in places)
        {
          'stopId': place.id,
          'dayNo': place.day,
          'orderNo': dayCounters.update(
            place.day,
            (value) => value + 1,
            ifAbsent: () => 1,
          ),
        },
    ];
  }

  TripAccessRole _roleForCurrentUser(List<TripMemberUi> members, String type) {
    if (type != 'GROUP') return TripAccessRole.personal;
    final currentUserId = _currentUserId;
    for (final member in members) {
      if (member.id == currentUserId) return member.role;
    }
    return TripAccessRole.member;
  }

  String get _currentUserId {
    final user = AuthService.instance.user;
    final id = _text(user?['id']);
    return id.isEmpty ? _text(user?['userId']) : id;
  }

  String get _currentUserName {
    final user = AuthService.instance.user;
    final displayName = _text(user?['displayName']);
    if (displayName.isNotEmpty) return displayName;
    final fullName = _text(user?['fullName']);
    if (fullName.isNotEmpty) return fullName;
    final nickname = _text(user?['nickname']);
    return nickname.isEmpty ? 'Bạn' : nickname;
  }

  static String _destination(Map<dynamic, dynamic> json) {
    final destination = _text(json['destination']);
    if (destination.isNotEmpty) return destination;
    return 'Đang cập nhật';
  }

  static int _days(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 1;
    return end.difference(start).inDays + 1;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static List<Object?> _asList(Object? value) {
    if (value is List) return value;
    return const <Object?>[];
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _plannedStartAt(
    DateTime? tripStartDate,
    int dayNo,
    String? startTime,
  ) {
    final parsed = _parseClock(startTime);
    if (tripStartDate == null || parsed == null) return null;
    final date = tripStartDate.add(Duration(days: dayNo - 1));
    return '${_date(date)}T'
        '${parsed.$1.toString().padLeft(2, '0')}:'
        '${parsed.$2.toString().padLeft(2, '0')}:00+07:00';
  }

  static String? _plannedEndAt(
    DateTime? tripStartDate,
    int dayNo,
    String? endTime,
  ) {
    final parsed = _parseClock(endTime);
    if (tripStartDate == null || parsed == null) return null;
    final date = tripStartDate.add(Duration(days: dayNo - 1));
    return '${_date(date)}T'
        '${parsed.$1.toString().padLeft(2, '0')}:'
        '${parsed.$2.toString().padLeft(2, '0')}:00+07:00';
  }

  static (int, int)? _parseClock(String? value) {
    final raw = value?.trim() ?? '';
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  static String _timeFromStart(Object? value) {
    final dateTime = _parseDateTime(value);
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static String? _nullableText(Object? value) {
    final text = _text(value).trim();
    return text.isEmpty ? null : text;
  }

  static String _text(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String _idText(Object? value) {
    if (value is num) return value.toString();
    return _text(value);
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}

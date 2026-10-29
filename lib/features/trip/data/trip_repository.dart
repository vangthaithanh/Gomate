import '../models/trip_planning_context.dart';
import '../../map/state/map_ui_session.dart';
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
  RealTripRepository({AuthService? auth})
    : _auth = auth ?? AuthService.instance;

  static final RealTripRepository instance = RealTripRepository();
  final AuthService _auth;
  static int pinRevision = 0;
  static final beforeUnpin = <Future<void> Function(String, String)>[];
  static final afterUnpin = <Future<void> Function(String, String)>[];
  static final afterPin = <Future<void> Function(String, String)>[];

  Future<TripPlanningContext> planningContext(String timezone) async {
    final path = Uri(
      path: '/trips/time-context',
      queryParameters: {'timezone': timezone},
    );
    final json = await _auth.request('GET', path.toString());
    return TripPlanningContext.fromJson(json);
  }

  Future<List<TripUi>> list() async {
    final response = await _auth.requestJson('GET', '/trips');
    return _asList(response).map(_fromSummary).toList(growable: false);
  }

  Future<List<TripInvitationUi>> incomingInvitations({
    String status = 'PENDING',
  }) async {
    final uri = Uri(
      path: '/trip-invitations/incoming',
      queryParameters: <String, String>{'status': status},
    );
    final response = await _auth.requestJson('GET', uri.toString());
    return _asList(response).map(_invitation).toList(growable: false);
  }

  Future<TripUi> detail(String tripId) async {
    final response = await _auth.request('GET', '/trips/$tripId');
    return _fromDetail(response);
  }

  Future<TripUi?> pinned() async {
    final response = await _auth.requestJson('GET', '/trips/pinned');
    if (response is Map<String, dynamic> && response['trip'] is Map) {
      return _fromDetail(response['trip']);
    }
    return null;
  }

  Future<TripUi> create(TripCreateDraft draft) async {
    final response = await _auth.request(
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
    final response = await _auth.request('GET', uri.toString());
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
    final response = await _auth.request('PATCH', '/trips/$tripId', body: body);
    return _fromDetail(response);
  }

  Future<void> delete(String tripId) async {
    await _auth.request('DELETE', '/trips/$tripId');
  }

  Future<TripUi> transferLeader(String tripId, String targetUserId) async {
    final response = await _auth.request(
      'PATCH',
      '/trips/$tripId/leader',
      body: {'targetUserId': targetUserId},
    );
    return _fromDetail(response);
  }

  Future<void> leave(String tripId) async {
    await _auth.request('DELETE', '/trips/$tripId/members/me');
  }

  Future<TripUi> removeMember(String tripId, String userId) async {
    final response = await _auth.request(
      'DELETE',
      '/trips/$tripId/members/$userId',
    );
    return _fromDetail(response);
  }

  Future<TripUi> pin(String tripId) async {
    final actor = _currentUserId;
    final selectionId = GoMateMapUiSession.displayedTrip?.id;
    final revision = ++pinRevision;
    final response = await _auth.request('POST', '/trips/$tripId/pin');
    final trip = _fromDetail(response);
    if (actor != _currentUserId || revision != pinRevision) {
      throw StateError(
        'Thao tác ghim đã thay đổi; hãy kiểm tra lịch trình đang ghim.',
      );
    }
    if (actor == _currentUserId && revision == pinRevision) {
      GoMateMapUiSession.pinTrip(
        trip,
        selectOnMap: GoMateMapUiSession.displayedTrip?.id == selectionId,
      );
      for (final hook in List.of(afterPin)) {
        if (actor != _currentUserId || revision != pinRevision) break;
        await hook(actor, tripId);
      }
    }
    return trip;
  }

  Future<void> unpin(String tripId) async {
    final actor = _currentUserId;
    final revision = ++pinRevision;
    for (final hook in List.of(beforeUnpin)) {
      await hook(actor, tripId);
    }
    if (actor != _currentUserId) return;
    await _auth.request('DELETE', '/trips/$tripId/pin');
    if (actor == _currentUserId && revision == pinRevision) {
      GoMateMapUiSession.clearPinnedTrip(tripId: tripId);
      for (final hook in List.of(afterUnpin)) {
        await hook(actor, tripId);
      }
    }
  }

  Future<void> publishLocation(
    String tripId, {
    required double latitude,
    required double longitude,
    double? accuracyM,
  }) async {
    await _auth.request(
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
    final response = await _auth.request(
      'POST',
      '/trips/$tripId/members',
      body: {'selectedMemberIds': ids},
    );
    return _fromDetail(response);
  }

  Future<TripInvitationUi> inviteMember(
    String tripId,
    String inviteeUserId,
  ) async {
    final response = await _auth.request(
      'POST',
      '/trips/$tripId/invitations',
      body: {'inviteeUserId': inviteeUserId.trim()},
    );
    return _invitation(response);
  }

  Future<TripUi> cancelInvitation(String tripId, String invitationId) async {
    final response = await _auth.request(
      'DELETE',
      '/trips/$tripId/invitations/$invitationId',
    );
    return _fromDetail(response);
  }

  Future<TripUi> acceptInvitation(String invitationId) async {
    final response = await _auth.request(
      'POST',
      '/trip-invitations/$invitationId/accept',
    );
    return _fromDetail(response);
  }

  Future<TripInvitationUi> declineInvitation(String invitationId) async {
    final response = await _auth.request(
      'POST',
      '/trip-invitations/$invitationId/decline',
    );
    return _invitation(response);
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

    final response = await _auth.request(
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
    bool clearTime = false,
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
    if (clearTime || (start == null && end != null)) {
      body['clearTime'] = true;
    } else if (start != null) {
      body['plannedStartAt'] = start;
      if (end != null) body['plannedEndAt'] = end;
    }

    final response = await _auth.request(
      'PATCH',
      '/trips/$tripId/stops/$stopId',
      body: body,
    );
    return _fromDetail(response);
  }

  Future<TripUi> deleteStop(String tripId, String stopId) async {
    await _auth.request('DELETE', '/trips/$tripId/stops/$stopId');
    return detail(tripId);
  }

  Future<TripUi> reorderStops(String tripId, List<TripPlaceUi> places) async {
    final response = await _auth.request(
      'PATCH',
      '/trips/$tripId/stops/reorder',
      body: {'stops': _stopOrderPayload(places)},
    );
    return _fromDetail(response);
  }

  Future<TripUi> optimizeStops(String tripId, {int? dayNo}) async {
    final body = <String, dynamic>{};
    if (dayNo != null) body['dayNo'] = dayNo;
    final response = await _auth.request(
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
          ? (_text(json['currentUserRole']) == 'LEADER'
                ? TripAccessRole.leader
                : TripAccessRole.member)
          : TripAccessRole.personal,
      startDate: start,
      endDate: end,
      timezone: _text(json['timezone'], fallback: 'Asia/Ho_Chi_Minh'),
      members: const <TripMemberUi>[],
      memberCount: _int(json['memberCount'], fallback: 1),
      conversationId: _nullableText(json['linkedConversationId']),
      places: _placeholderStops(_int(json['stopCount'])),
      isDetail: false,
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
      timezone: _text(json['timezone'], fallback: 'Asia/Ho_Chi_Minh'),
      members: members,
      pendingInvitees: _asList(json['pendingInvitations'])
          .whereType<Map>()
          .map(
            (invite) => TripMemberUi(
              id: _text(invite['inviteeUserId']),
              invitationId: _nullableText(invite['invitationId']),
              name: _text(invite['inviteeDisplayName'], fallback: 'Người dùng'),
              avatarAsset: _text(invite['inviteeAvatarUrl']),
            ),
          )
          .toList(growable: false),
      pendingInviteIds: _asList(json['pendingInvitations'])
          .whereType<Map>()
          .map((invite) => _text(invite['inviteeUserId']))
          .toList(growable: false),
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

  TripInvitationUi _invitation(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final inviterName = _text(
      json['inviterDisplayName'],
      fallback: 'Một người bạn',
    );
    return TripInvitationUi(
      invitationId: _text(json['invitationId']),
      tripId: _text(json['tripId']),
      tripTitle: _text(json['tripTitle'], fallback: 'Lịch trình'),
      inviterUserId: _text(json['inviterUserId']),
      inviterName: inviterName,
      inviterAvatarUrl: _nullableText(json['inviterAvatarUrl']),
      status: _text(json['status'], fallback: 'PENDING'),
      createdAt: _parseDateTime(json['createdAt']),
      respondedAt: _parseDateTime(json['respondedAt']),
    );
  }

  TripPlaceUi _stop(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return TripPlaceUi(
      id: _text(json['id']),
      placeId: _idText(json['placeId']),
      name: _text(json['name'], fallback: 'Địa điểm'),
      day: _int(json['dayNo'], fallback: 1),
      // Wall values are derived by Spring using the Trip IANA timezone.
      // Never interpret them using the phone's timezone.
      startTime: _timeFromStart(
        json['plannedLocalStartAt'] ?? json['plannedStartAt'],
      ),
      endTime: _timeFromStart(
        json['plannedLocalEndAt'] ?? json['plannedEndAt'],
      ),
      plannedStartAt: _nullableText(json['plannedStartAt']),
      plannedEndAt: _nullableText(json['plannedEndAt']),
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
    final user = _auth.user;
    final id = _text(user?['id']);
    return id.isEmpty ? _text(user?['userId']) : id;
  }

  String get _currentUserName {
    final user = _auth.user;
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
    return DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
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
    if (startTime == null || startTime.trim().isEmpty) return null;
    if (tripStartDate == null || parsed == null) {
      throw ArgumentError('Ngày/giờ địa điểm không hợp lệ.');
    }
    final date = DateTime.utc(
      tripStartDate.year,
      tripStartDate.month,
      tripStartDate.day + dayNo - 1,
    );
    return '${_date(date)}T'
        '${parsed.$1.toString().padLeft(2, '0')}:'
        '${parsed.$2.toString().padLeft(2, '0')}:00';
  }

  static String? _plannedEndAt(
    DateTime? tripStartDate,
    int dayNo,
    String? endTime,
  ) {
    final parsed = _parseClock(endTime);
    if (endTime == null || endTime.trim().isEmpty) return null;
    if (tripStartDate == null || parsed == null) {
      throw ArgumentError('Ngày/giờ địa điểm không hợp lệ.');
    }
    final date = DateTime.utc(
      tripStartDate.year,
      tripStartDate.month,
      tripStartDate.day + dayNo - 1,
    );
    return '${_date(date)}T'
        '${parsed.$1.toString().padLeft(2, '0')}:'
        '${parsed.$2.toString().padLeft(2, '0')}:00';
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
    // This is an explicitly Trip-local wall timestamp, not an instant.
    final dateTime = value is String ? DateTime.tryParse(value) : null;
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

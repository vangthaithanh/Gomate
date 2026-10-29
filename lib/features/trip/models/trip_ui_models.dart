enum TripAccessRole { personal, member, leader }

class TripInvitationUi {
  final String invitationId;
  final String tripId;
  final String tripTitle;
  final String inviterUserId;
  final String inviterName;
  final String? inviterAvatarUrl;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const TripInvitationUi({
    required this.invitationId,
    required this.tripId,
    required this.tripTitle,
    required this.inviterUserId,
    required this.inviterName,
    this.inviterAvatarUrl,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });
}

class TripPlaceUi {
  /// UI id tạm thời để reorder/xóa ổn định.
  /// Khi lấy từ backend, đây là trip_stops.id.
  final String id;

  /// GoMate places.id thật, dùng để gọi Trip Stop API và kiểm tra trùng kề nhau.
  final String placeId;

  final String name;
  final String startTime;
  final String endTime;
  final String? plannedStartAt;
  final String? plannedEndAt;
  final bool hasCompleteInterval;
  final int day;

  /// Chỉ phục vụ UI Map hiện tại.
  final String? imageAsset;
  final String? imageUrl;

  const TripPlaceUi({
    this.id = '',
    this.placeId = '',
    required this.name,
    this.startTime = '',
    this.endTime = '',
    this.plannedStartAt,
    this.plannedEndAt,
    this.hasCompleteInterval = false,
    required this.day,
    this.imageAsset,
    this.imageUrl,
  });

  bool get hasStartTime => startTime.trim().isNotEmpty;

  bool get hasEndTime => endTime.trim().isNotEmpty;

  bool get hasFullTime => hasCompleteInterval && hasStartTime && hasEndTime;

  TripPlaceUi copyWith({
    String? id,
    String? placeId,
    String? name,
    String? startTime,
    String? endTime,
    bool? hasCompleteInterval,
    int? day,
    String? imageAsset,
    String? imageUrl,
  }) {
    return TripPlaceUi(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      plannedStartAt: plannedStartAt,
      plannedEndAt: plannedEndAt,
      hasCompleteInterval: hasCompleteInterval ?? this.hasCompleteInterval,
      day: day ?? this.day,
      imageAsset: imageAsset ?? this.imageAsset,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class TripMemberUi {
  final String id;

  /// Only set for pending invitees; never interchangeable with the user ID.
  final String? invitationId;
  final String name;
  final String subtitle;
  final String avatarAsset;
  final TripAccessRole role;
  final String lastSeen;

  const TripMemberUi({
    this.id = '',
    this.invitationId,
    required this.name,
    this.subtitle = '',
    this.avatarAsset = '',
    TripAccessRole role = TripAccessRole.member,
    bool isOwner = false,
    this.lastSeen = 'Vừa xong',
  }) : role = isOwner ? TripAccessRole.leader : role;

  bool get isOwner => role == TripAccessRole.leader;

  bool get isLeader => role == TripAccessRole.leader;
}

class TripUi {
  /// Summary responses never own stop occurrences or their saved times.
  final bool isDetail;
  final String id;
  final String title;
  final int days;
  final String destination;
  final String coverAsset;
  final bool isActive;

  /// Chỉ true khi đã có ít nhất một member khác chấp nhận.
  final bool isGroup;

  final TripAccessRole currentUserRole;

  final DateTime? startDate;
  final DateTime? endDate;
  final String timezone;

  final List<TripPlaceUi> places;
  final List<TripMemberUi> members;

  /// List responses have a count but do not include the complete roster.
  final int? _summaryMemberCount;
  final List<String> pendingInviteIds;
  final List<TripMemberUi> pendingInvitees;
  final String? conversationId;

  const TripUi({
    this.isDetail = true,
    required this.id,
    required this.title,
    required this.days,
    required this.destination,
    this.coverAsset = 'assets/images/home_dalat.jpg',
    this.isActive = false,
    this.isGroup = false,
    this.currentUserRole = TripAccessRole.personal,
    this.startDate,
    this.endDate,
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.places = const <TripPlaceUi>[],
    this.members = const <TripMemberUi>[],
    int? memberCount,
    this.pendingInviteIds = const <String>[],
    this.pendingInvitees = const <TripMemberUi>[],
    this.conversationId,
  }) : _summaryMemberCount = memberCount;

  /// Giữ logic quyền hiện tại của project:
  /// personal/leader được chỉnh; member chỉ xem.
  // isActive is the existing UI pin flag, not a Trip journey status.
  bool get canEditTrip => canDeleteTrip;

  bool get canDeleteTrip =>
      !isGroup || currentUserRole == TripAccessRole.leader;

  bool get canLeaveTrip => isGroup && currentUserRole != TripAccessRole.leader;

  bool get hasChat =>
      isGroup && conversationId != null && conversationId!.trim().isNotEmpty;

  int get memberCount =>
      _summaryMemberCount ?? (members.isEmpty ? 1 : members.length);

  bool get hasPendingInvites => pendingInviteIds.isNotEmpty;

  String get roleLabel {
    switch (currentUserRole) {
      case TripAccessRole.personal:
        return 'Cá nhân';
      case TripAccessRole.member:
        return 'Thành viên';
      case TripAccessRole.leader:
        return 'Nhóm trưởng';
    }
  }

  String get dateRangeLabel {
    if (startDate == null || endDate == null) {
      return 'Chưa chọn ngày';
    }

    return '${_date(startDate!)} - ${_date(endDate!)}';
  }

  String get weekdayRangeLabel {
    if (startDate == null || endDate == null) {
      return '';
    }

    return '${_weekday(startDate!)} - ${_weekday(endDate!)}';
  }

  TripUi copyWith({
    bool? isDetail,
    String? id,
    String? title,
    int? days,
    String? destination,
    String? coverAsset,
    bool? isActive,
    bool? isGroup,
    TripAccessRole? currentUserRole,
    DateTime? startDate,
    DateTime? endDate,
    String? timezone,
    List<TripPlaceUi>? places,
    List<TripMemberUi>? members,
    int? memberCount,
    List<String>? pendingInviteIds,
    List<TripMemberUi>? pendingInvitees,
    String? conversationId,
  }) {
    return TripUi(
      isDetail: isDetail ?? this.isDetail,
      id: id ?? this.id,
      title: title ?? this.title,
      days: days ?? this.days,
      destination: destination ?? this.destination,
      coverAsset: coverAsset ?? this.coverAsset,
      isActive: isActive ?? this.isActive,
      isGroup: isGroup ?? this.isGroup,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timezone: timezone ?? this.timezone,
      places: places ?? this.places,
      members: members ?? this.members,
      memberCount:
          memberCount ?? (members == null ? _summaryMemberCount : null),
      pendingInviteIds: pendingInviteIds ?? this.pendingInviteIds,
      pendingInvitees: pendingInvitees ?? this.pendingInvitees,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  static String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  static String _weekday(DateTime value) {
    const labels = <String>[
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'C.Nhật',
    ];

    return labels[value.weekday];
  }
}

class TripDateRangeResult {
  final DateTime startDate;
  final DateTime endDate;

  const TripDateRangeResult({required this.startDate, required this.endDate});

  int get days => endDate.difference(startDate).inDays + 1;
}

class TripDetailResult {
  final TripUi trip;
  final bool removeFromList;

  const TripDetailResult({required this.trip, this.removeFromList = false});
}

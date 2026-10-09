enum TripAccessRole {
  personal,
  member,
  deputy,
  leader,
}

class TripPlaceUi {
  /// UI id tạm thời để reorder/xóa ổn định.
  /// Backend sau này thay bằng tripPlaceId/placeId thật.
  final String id;

  final String name;
  final String startTime;
  final String endTime;
  final int day;

  /// Chỉ phục vụ UI Map hiện tại.
  final String? imageAsset;
  final String? imageUrl;

  const TripPlaceUi({
    this.id = '',
    required this.name,
    this.startTime = '',
    this.endTime = '',
    required this.day,
    this.imageAsset,
    this.imageUrl,
  });

  bool get hasStartTime =>
      startTime.trim().isNotEmpty;

  bool get hasEndTime =>
      endTime.trim().isNotEmpty;

  bool get hasFullTime =>
      hasStartTime && hasEndTime;

  TripPlaceUi copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    int? day,
    String? imageAsset,
    String? imageUrl,
  }) {
    return TripPlaceUi(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      day: day ?? this.day,
      imageAsset: imageAsset ?? this.imageAsset,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class TripMemberUi {
  final String id;
  final String name;
  final String subtitle;
  final String avatarAsset;
  final TripAccessRole role;
  final String lastSeen;

  const TripMemberUi({
    this.id = '',
    required this.name,
    this.subtitle = '',
    this.avatarAsset = '',
    TripAccessRole role = TripAccessRole.member,
    bool isOwner = false,
    this.lastSeen = 'Vừa xong',
  }) : role = isOwner ? TripAccessRole.leader : role;

  bool get isOwner =>
      role == TripAccessRole.leader;

  bool get isLeader =>
      role == TripAccessRole.leader;

  bool get isDeputy =>
      role == TripAccessRole.deputy;
}

class TripUi {
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

  final List<TripPlaceUi> places;
  final List<TripMemberUi> members;
  final List<String> pendingInviteIds;
  final String? conversationId;

  const TripUi({
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
    this.places = const <TripPlaceUi>[],
    this.members = const <TripMemberUi>[],
    this.pendingInviteIds = const <String>[],
    this.conversationId,
  });

  /// Giữ logic quyền hiện tại của project:
  /// personal/leader được chỉnh; deputy/member chỉ xem.
  bool get canEditTrip =>
      !isGroup ||
      currentUserRole == TripAccessRole.leader;

  bool get canDeleteTrip =>
      !isGroup ||
      currentUserRole == TripAccessRole.leader;

  bool get canLeaveTrip =>
      isGroup &&
      currentUserRole != TripAccessRole.leader;

  bool get hasChat =>
      isGroup &&
      conversationId != null &&
      conversationId!.trim().isNotEmpty;

  int get memberCount =>
      members.isEmpty ? 1 : members.length;

  bool get hasPendingInvites =>
      pendingInviteIds.isNotEmpty;

  String get roleLabel {
    switch (currentUserRole) {
      case TripAccessRole.personal:
        return 'Cá nhân';
      case TripAccessRole.member:
        return 'Thành viên';
      case TripAccessRole.deputy:
        return 'Nhóm phó';
      case TripAccessRole.leader:
        return 'Nhóm trưởng';
    }
  }

  String get dateRangeLabel {
    if (startDate == null ||
        endDate == null) {
      return 'Chưa chọn ngày';
    }

    return '${_date(startDate!)} - ${_date(endDate!)}';
  }

  String get weekdayRangeLabel {
    if (startDate == null ||
        endDate == null) {
      return '';
    }

    return '${_weekday(startDate!)} - ${_weekday(endDate!)}';
  }

  TripUi copyWith({
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
    List<TripPlaceUi>? places,
    List<TripMemberUi>? members,
    List<String>? pendingInviteIds,
    String? conversationId,
  }) {
    return TripUi(
      id: id ?? this.id,
      title: title ?? this.title,
      days: days ?? this.days,
      destination:
          destination ?? this.destination,
      coverAsset:
          coverAsset ?? this.coverAsset,
      isActive:
          isActive ?? this.isActive,
      isGroup:
          isGroup ?? this.isGroup,
      currentUserRole:
          currentUserRole ??
              this.currentUserRole,
      startDate:
          startDate ?? this.startDate,
      endDate:
          endDate ?? this.endDate,
      places:
          places ?? this.places,
      members:
          members ?? this.members,
      pendingInviteIds:
          pendingInviteIds ??
              this.pendingInviteIds,
      conversationId:
          conversationId ??
              this.conversationId,
    );
  }

  static String _date(
    DateTime value,
  ) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  static String _weekday(
    DateTime value,
  ) {
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

  const TripDateRangeResult({
    required this.startDate,
    required this.endDate,
  });

  int get days =>
      endDate.difference(startDate).inDays +
      1;
}

class TripDetailResult {
  final TripUi trip;
  final bool removeFromList;

  const TripDetailResult({
    required this.trip,
    this.removeFromList = false,
  });
}

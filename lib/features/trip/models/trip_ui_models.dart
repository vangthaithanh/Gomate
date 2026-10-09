enum TripAccessRole {
  personal,
  member,
  deputy,
  leader,
}

class TripPlaceUi {
  final String name;
  final String startTime;
  final String endTime;
  final int day;

  const TripPlaceUi({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  TripPlaceUi copyWith({
    String? name,
    String? startTime,
    String? endTime,
    int? day,
  }) {
    return TripPlaceUi(
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      day: day ?? this.day,
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

  /// Giữ tương thích với code Trip cũ:
  ///
  /// TripMemberUi(name: 'Thune', isOwner: true)
  ///
  /// và code mới:
  ///
  /// TripMemberUi(
  ///   id: 'me',
  ///   name: 'Thune',
  ///   role: TripAccessRole.leader,
  /// )
  const TripMemberUi({
    this.id = '',
    required this.name,
    this.subtitle = '',
    this.avatarAsset = '',
    TripAccessRole role = TripAccessRole.member,
    bool isOwner = false,
    this.lastSeen = 'Vừa xong',
  }) : role = isOwner ? TripAccessRole.leader : role;

  bool get isOwner => role == TripAccessRole.leader;
  bool get isLeader => role == TripAccessRole.leader;
  bool get isDeputy => role == TripAccessRole.deputy;
}

class TripUi {
  final String id;
  final String title;
  final int days;
  final String destination;
  final String coverAsset;
  final bool isActive;

  /// Chỉ true khi đã có ít nhất một thành viên khác CHẤP NHẬN tham gia.
  ///
  /// Người chỉ mới được mời không làm lịch trình trở thành lịch trình nhóm.
  final bool isGroup;

  final TripAccessRole currentUserRole;

  final DateTime? startDate;
  final DateTime? endDate;

  final List<TripPlaceUi> places;

  /// Danh sách thành viên đã tham gia/đã chấp nhận.
  ///
  /// Với lịch trình cá nhân mới tạo, danh sách này chỉ có current user.
  final List<TripMemberUi> members;

  /// Danh sách lời mời đang chờ.
  ///
  /// Đây là UI state phục vụ demo. Backend sau này sẽ quản lý trạng thái
  /// pending/accepted/rejected và thời điểm gửi notification.
  final List<String> pendingInviteIds;

  /// Chỉ có sau khi lịch trình thực sự trở thành nhóm và group chat được tạo.
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

  bool get canEditTrip =>
      !isGroup || currentUserRole == TripAccessRole.leader;

  bool get canDeleteTrip =>
      !isGroup || currentUserRole == TripAccessRole.leader;

  bool get canLeaveTrip =>
      isGroup && currentUserRole != TripAccessRole.leader;

  bool get hasChat =>
      isGroup &&
      conversationId != null &&
      conversationId!.trim().isNotEmpty;

  int get memberCount => members.isEmpty ? 1 : members.length;

  bool get hasPendingInvites => pendingInviteIds.isNotEmpty;

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
      destination: destination ?? this.destination,
      coverAsset: coverAsset ?? this.coverAsset,
      isActive: isActive ?? this.isActive,
      isGroup: isGroup ?? this.isGroup,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      places: places ?? this.places,
      members: members ?? this.members,
      pendingInviteIds: pendingInviteIds ?? this.pendingInviteIds,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}';

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

  const TripDateRangeResult({
    required this.startDate,
    required this.endDate,
  });

  int get days => endDate.difference(startDate).inDays + 1;
}

class TripDetailResult {
  final TripUi trip;
  final bool removeFromList;

  const TripDetailResult({
    required this.trip,
    this.removeFromList = false,
  });
}

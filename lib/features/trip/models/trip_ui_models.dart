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
  final String name;
  final String avatarAsset;
  final bool isOwner;
  final String lastSeen;

  const TripMemberUi({
    required this.name,
    this.avatarAsset = '',
    this.isOwner = false,
    this.lastSeen = 'Vừa xong',
  });
}

class TripUi {
  final String id;
  final String title;
  final int days;
  final String destination;
  final String coverAsset;
  final bool isActive;
  final bool isGroup;
  final List<TripPlaceUi> places;
  final List<TripMemberUi> members;

  const TripUi({
    required this.id,
    required this.title,
    required this.days,
    required this.destination,
    this.coverAsset = 'assets/images/home_dalat.jpg',
    this.isActive = false,
    this.isGroup = false,
    this.places = const [],
    this.members = const [],
  });

  TripUi copyWith({
    String? id,
    String? title,
    int? days,
    String? destination,
    String? coverAsset,
    bool? isActive,
    bool? isGroup,
    List<TripPlaceUi>? places,
    List<TripMemberUi>? members,
  }) {
    return TripUi(
      id: id ?? this.id,
      title: title ?? this.title,
      days: days ?? this.days,
      destination: destination ?? this.destination,
      coverAsset: coverAsset ?? this.coverAsset,
      isActive: isActive ?? this.isActive,
      isGroup: isGroup ?? this.isGroup,
      places: places ?? this.places,
      members: members ?? this.members,
    );
  }
}

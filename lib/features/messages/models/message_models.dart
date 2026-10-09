enum MessageConversationType {
  direct,
  group,
}

enum MessageGroupRole {
  member,
  deputy,
  leader,
}

class MessageParticipant {
  final String id;
  final String name;
  final String? avatarAsset;
  final String? nickname;
  final MessageGroupRole role;
  final String? distanceLabel;

  const MessageParticipant({
    required this.id,
    required this.name,
    this.avatarAsset,
    this.nickname,
    this.role = MessageGroupRole.member,
    this.distanceLabel,
  });

  String get displayName {
    final value = nickname?.trim();
    return value == null || value.isEmpty ? name : value;
  }

  MessageParticipant copyWith({
    String? name,
    String? avatarAsset,
    String? nickname,
    bool clearNickname = false,
    MessageGroupRole? role,
    String? distanceLabel,
  }) {
    return MessageParticipant(
      id: id,
      name: name ?? this.name,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      role: role ?? this.role,
      distanceLabel: distanceLabel ?? this.distanceLabel,
    );
  }
}

class MessageItem {
  final String id;
  final String senderId;
  final String text;
  final String sentAtLabel;
  final bool readByCurrentUser;
  final String? dateLabel;

  const MessageItem({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAtLabel,
    this.readByCurrentUser = true,
    this.dateLabel,
  });
}

class MessageGroupInvite {
  final String contactId;
  final String name;
  final String subtitle;
  final String? avatarAsset;
  final String invitedById;

  const MessageGroupInvite({
    required this.contactId,
    required this.name,
    required this.subtitle,
    required this.invitedById,
    this.avatarAsset,
  });
}

class MessageConversation {
  final String id;
  final MessageConversationType type;
  final String title;
  final String? coverAsset;
  final List<MessageParticipant> participants;
  final List<MessageItem> messages;

  final String lastSenderId;
  final String lastMessageText;
  final String lastMessageTime;
  final int unreadCount;

  final bool isPending;
  final bool isMuted;

  /// Chỉ áp dụng cho direct chat.
  ///
  /// Khi true:
  /// - lịch sử chat vẫn được giữ;
  /// - conversation vẫn mở được;
  /// - composer bị khoá và thay bằng CTA "Bỏ chặn";
  /// - không được gửi tin nhắn mới cho đến khi unblocked.
  final bool isBlocked;
  final String activityLabel;
  final List<String> mediaAssets;
  final List<String> links;

  /// Group chat và group itinerary là một cặp nghiệp vụ.
  /// Mọi conversation type=group phải có linkedItineraryId.
  final String? linkedItineraryId;

  final List<MessageGroupInvite> pendingInvites;

  const MessageConversation({
    required this.id,
    required this.type,
    required this.title,
    required this.participants,
    required this.messages,
    required this.lastSenderId,
    required this.lastMessageText,
    required this.lastMessageTime,
    this.coverAsset,
    this.unreadCount = 0,
    this.isPending = false,
    this.isMuted = false,
    this.isBlocked = false,
    this.activityLabel = 'Hoạt động gần đây',
    this.mediaAssets = const <String>[],
    this.links = const <String>[],
    this.linkedItineraryId,
    this.pendingInvites = const <MessageGroupInvite>[],
  }) : assert(
          type != MessageConversationType.group || linkedItineraryId != null,
          'Group message phải gắn với một lịch trình nhóm.',
        );

  bool get isGroup => type == MessageConversationType.group;

  MessageGroupRole roleOf(String userId) {
    for (final participant in participants) {
      if (participant.id == userId) return participant.role;
    }
    return MessageGroupRole.member;
  }

  MessageConversation copyWith({
    String? title,
    String? coverAsset,
    List<MessageParticipant>? participants,
    List<MessageItem>? messages,
    String? lastSenderId,
    String? lastMessageText,
    String? lastMessageTime,
    int? unreadCount,
    bool? isPending,
    bool? isMuted,
    bool? isBlocked,
    String? activityLabel,
    List<String>? mediaAssets,
    List<String>? links,
    String? linkedItineraryId,
    List<MessageGroupInvite>? pendingInvites,
  }) {
    return MessageConversation(
      id: id,
      type: type,
      title: title ?? this.title,
      coverAsset: coverAsset ?? this.coverAsset,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPending: isPending ?? this.isPending,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked ?? this.isBlocked,
      activityLabel: activityLabel ?? this.activityLabel,
      mediaAssets: mediaAssets ?? this.mediaAssets,
      links: links ?? this.links,
      linkedItineraryId: linkedItineraryId ?? this.linkedItineraryId,
      pendingInvites: pendingInvites ?? this.pendingInvites,
    );
  }
}

class MessageContact {
  final String id;
  final String name;
  final String subtitle;
  final String? avatarAsset;

  const MessageContact({
    required this.id,
    required this.name,
    required this.subtitle,
    this.avatarAsset,
  });
}

class MessageSearchResult {
  final String messageId;
  final String senderName;
  final String text;

  const MessageSearchResult({
    required this.messageId,
    required this.senderName,
    required this.text,
  });
}

class MessageItinerary {
  final String id;
  final String title;
  final String dateRange;
  final String summary;
  final String imageAsset;
  final int memberCount;

  /// Current user có quyền mời thêm người vào lịch trình này hay không.
  /// Group itinerary do conversation quản lý riêng sẽ để false.
  final bool canInviteMembers;

  const MessageItinerary({
    required this.id,
    required this.title,
    required this.dateRange,
    required this.summary,
    required this.imageAsset,
    this.memberCount = 0,
    this.canInviteMembers = false,
  });
}

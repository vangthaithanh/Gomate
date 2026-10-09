import 'package:flutter/foundation.dart';

import '../models/message_models.dart';

abstract class MessageRepository extends ChangeNotifier {
  String get currentUserId;
  String get currentUserName;

  List<MessageConversation> get mainConversations;
  List<MessageConversation> get pendingConversations;
  List<MessageContact> get contacts;
  List<MessageItinerary> get itineraries;

  /// Chỉ các lịch trình current user có quyền mời thêm thành viên.
  List<MessageItinerary> get inviteableItineraries;

  MessageConversation? conversation(String id);
  MessageItinerary? linkedGroupItinerary(String conversationId);
  MessageGroupRole groupRole(String conversationId);
  List<MessageGroupInvite> pendingGroupInvites(String conversationId);
  List<MessageContact> searchContacts(String query);
  List<MessageSearchResult> searchMessages(String conversationId, String query);
  String openOrCreateDirectConversation(String contactId);

  void markRead(String conversationId);
  void acceptPending(Iterable<String> conversationIds);
  void deletePending(Iterable<String> conversationIds);
  void blockConversation(String conversationId);
  void unblockConversation(String conversationId);
  void leaveGroup(String conversationId);
  void deleteGroupAndItinerary(String conversationId);
  void renameGroup(String conversationId, String name);
  void inviteGroupMembers(String conversationId, Iterable<String> contactIds);
  void cancelGroupInvite(String conversationId, String contactId);
  void removeGroupMembers(String conversationId, Iterable<String> participantIds);
  void promoteGroupMembers(String conversationId, Iterable<String> participantIds);
  void revokeGroupDeputy(String conversationId, String participantId);
  void toggleMute(String conversationId);
  void setNickname({
    required String conversationId,
    required String participantId,
    String? nickname,
  });
  void sendText({
    required String conversationId,
    required String text,
  });
  void invitePeerToItinerary({
    required String conversationId,
    required String itineraryId,
  });
}

class DemoMessageRepository extends MessageRepository {
  DemoMessageRepository._() {
    _seed();
  }

  static final DemoMessageRepository instance = DemoMessageRepository._();

  @override
  final String currentUserId = 'me';

  @override
  final String currentUserName = 'Thune';

  final List<MessageConversation> _items = <MessageConversation>[];

  /// Mock state cho lời mời từ direct chat vào lịch trình.
  /// Key = "<itineraryId>:<inviteeUserId>".
  final Set<String> _pendingDirectItineraryInvites = <String>{};

  final List<MessageContact> _contacts = const <MessageContact>[
    MessageContact(
      id: 'chi',
      name: 'ChiThanh',
      subtitle: 'ChiThanh',
      avatarAsset: 'assets/images/thiennhien.jpg',
    ),
    MessageContact(
      id: 'thune_a',
      name: 'Thune',
      subtitle: 'Thanh Thúy',
      avatarAsset: 'assets/images/nghiduong.jpg',
    ),
    MessageContact(
      id: 'dada_1',
      name: 'DaDaDa',
      subtitle: 'Thanh Thúy',
      avatarAsset: 'assets/images/ketban.jpg',
    ),
    MessageContact(
      id: 'dada_2',
      name: 'DaDaDa',
      subtitle: 'Thanh Thúy',
      avatarAsset: 'assets/images/lichsu.jpg',
    ),
    MessageContact(
      id: 'thanh',
      name: 'Thanh',
      subtitle: 'ChiThanh',
      avatarAsset: 'assets/images/checkin.jpg',
    ),
    MessageContact(
      id: 'xuan_thu',
      name: 'Xuân Thu',
      subtitle: 'Thune',
      avatarAsset: 'assets/images/survey_city.jpg',
    ),
    MessageContact(
      id: 'trong_bui',
      name: 'Trọng Bùi',
      subtitle: 'Buiji',
      avatarAsset: 'assets/images/survey_country.jpg',
    ),
    MessageContact(
      id: 'thanh_2',
      name: 'Thanh',
      subtitle: 'ChiThanh',
      avatarAsset: 'assets/images/survey_beach.jpg',
    ),
    MessageContact(
      id: 'trong_bui_2',
      name: 'Trọng Bùi',
      subtitle: 'Buiji',
      avatarAsset: 'assets/images/survey_resort.jpg',
    ),
  ];

  final List<MessageItinerary> _itineraries = <MessageItinerary>[
    const MessageItinerary(
      id: 'trip_da_lat_member',
      title: 'Đà Lạt ơi',
      dateRange: '12-15 tháng 10, 2026',
      summary: '4 ngày - 12 địa điểm',
      imageAsset: 'assets/images/thiennhien.jpg',
      memberCount: 4,
    ),
    const MessageItinerary(
      id: 'trip_da_lat_leader',
      title: 'Đà Lạt ơi',
      dateRange: '12-15 tháng 10, 2026',
      summary: '4 ngày - 12 địa điểm',
      imageAsset: 'assets/images/checkin.jpg',
      memberCount: 4,
    ),
    const MessageItinerary(
      id: 'trip_da_lat_deputy',
      title: 'Đà Lạt ơi',
      dateRange: '12-15 tháng 10, 2026',
      summary: '4 ngày - 12 địa điểm',
      imageAsset: 'assets/images/survey_city.jpg',
      memberCount: 4,
    ),
    const MessageItinerary(
      id: 'trip_personal_da_lat',
      title: 'Đà lạt ơi',
      dateRange: '12-15 tháng 10, 2026',
      summary: '4 ngày - 12 địa điểm',
      imageAsset: 'assets/images/survey_city.jpg',
      memberCount: 4,
      canInviteMembers: true,
    ),
    const MessageItinerary(
      id: 'trip_personal_vung_tau_1',
      title: 'Biển vũng tàu',
      dateRange: '20-22 tháng 10, 2026',
      summary: '3 ngày - 8 địa điểm',
      imageAsset: 'assets/images/thiennhien.jpg',
      canInviteMembers: true,
    ),
    const MessageItinerary(
      id: 'trip_personal_vung_tau_2',
      title: 'Biển vũng tàu',
      dateRange: '02-04 tháng 11, 2026',
      summary: '3 ngày - 6 địa điểm',
      imageAsset: 'assets/images/survey_city.jpg',
      memberCount: 2,
      canInviteMembers: true,
    ),
  ];


  MessageParticipant get _me => const MessageParticipant(
        id: 'me',
        name: 'Thune',
      );

  MessageParticipant get _meLeader => const MessageParticipant(
        id: 'me',
        name: 'Thune',
        role: MessageGroupRole.leader,
      );

  MessageParticipant get _meDeputy => const MessageParticipant(
        id: 'me',
        name: 'Thune',
        role: MessageGroupRole.deputy,
      );

  MessageParticipant get _chiDeputy => const MessageParticipant(
        id: 'chi',
        name: 'ChiThanh',
        avatarAsset: 'assets/images/thiennhien.jpg',
        role: MessageGroupRole.deputy,
        distanceLabel: '12.5km',
      );

  MessageParticipant get _chiMember => const MessageParticipant(
        id: 'chi',
        name: 'ChiThanh',
        avatarAsset: 'assets/images/thiennhien.jpg',
        distanceLabel: '12.5km',
      );

  MessageParticipant get _thuneAMember => const MessageParticipant(
        id: 'thune_a',
        name: 'Thune',
        avatarAsset: 'assets/images/nghiduong.jpg',
        distanceLabel: 'Chưa xác định km',
      );

  MessageParticipant get _trongBui => const MessageParticipant(
        id: 'trong_bui',
        name: 'Trọng Bùi',
        avatarAsset: 'assets/images/survey_country.jpg',
        nickname: 'Buiji',
        distanceLabel: 'Chưa xác định km',
      );

  MessageParticipant get _chi => const MessageParticipant(
        id: 'chi',
        name: 'ChiThanh',
        avatarAsset: 'assets/images/thiennhien.jpg',
        role: MessageGroupRole.leader,
        distanceLabel: '12.5km',
      );

  MessageParticipant get _thuneA => const MessageParticipant(
        id: 'thune_a',
        name: 'Thune',
        avatarAsset: 'assets/images/nghiduong.jpg',
        role: MessageGroupRole.deputy,
        distanceLabel: 'Chưa xác định km',
      );

  MessageParticipant get _thanh => const MessageParticipant(
        id: 'thanh',
        name: 'Thanh',
        avatarAsset: 'assets/images/checkin.jpg',
        nickname: 'ChiThanh',
        distanceLabel: '12.5km',
      );

  void _seed() {
    _items
      ..clear()
      ..addAll([
        MessageConversation(
          id: 'direct_chi',
          type: MessageConversationType.direct,
          title: 'ChiThanh',
          participants: [_me, _chi],
          messages: const [
            MessageItem(
              id: 'dc_1',
              senderId: 'me',
              text: 'This is the main chat template',
              sentAtLabel: '18:20',
              dateLabel: '18:20, 2 tháng 8',
            ),
            MessageItem(
              id: 'dc_2',
              senderId: 'chi',
              text: 'Oh?',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'dc_3',
              senderId: 'chi',
              text: 'Cool',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'dc_4',
              senderId: 'chi',
              text: 'How does it work?',
              sentAtLabel: '18:22',
            ),
            MessageItem(
              id: 'dc_5',
              senderId: 'me',
              text:
                  'You just edit any text to type in the conversation you want to show, and delete any bubbles you don’t want to use',
              sentAtLabel: '18:20',
              dateLabel: '18:20, TH 5',
            ),
            MessageItem(
              id: 'dc_6',
              senderId: 'me',
              text: 'Boom!',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'dc_7',
              senderId: 'chi',
              text: 'Oh?',
              sentAtLabel: '18:22',
            ),
            MessageItem(
              id: 'dc_8',
              senderId: 'chi',
              text: 'How does it work?',
              sentAtLabel: '18:23',
            ),
            MessageItem(
              id: 'dc_9',
              senderId: 'me',
              text: 'This is the main chat template',
              sentAtLabel: '18:24',
            ),
          ],
          lastSenderId: 'me',
          lastMessageText: 'This is the main chat template',
          lastMessageTime: '4 giờ trước',
          activityLabel: 'Hoạt động 2 giờ trước',
          mediaAssets: const [
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
          ],
          links: const ['Tên đường link', 'Tên đường link'],
        ),
        MessageConversation(
          id: 'direct_read',
          type: MessageConversationType.direct,
          title: 'Thune',
          participants: [_me, _thuneA],
          messages: const [
            MessageItem(
              id: 'dr_1',
              senderId: 'thune_a',
              text: 'Nhớ sửa lại nhe',
              sentAtLabel: '3 ngày',
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Nhớ sửa lại nhe',
          lastMessageTime: '3 ngày',
        ),
        MessageConversation(
          id: 'direct_unread_1',
          type: MessageConversationType.direct,
          title: 'Thune',
          participants: [_me, _thuneA],
          messages: const [
            MessageItem(
              id: 'du1_1',
              senderId: 'thune_a',
              text: 'Bạn xem giúp mình nhé',
              sentAtLabel: '3 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Bạn xem giúp mình nhé',
          lastMessageTime: '3 ngày',
          unreadCount: 1,
        ),
        MessageConversation(
          id: 'direct_unread_5',
          type: MessageConversationType.direct,
          title: 'Thune',
          participants: [_me, _thuneA],
          messages: const [
            MessageItem(
              id: 'du5_1',
              senderId: 'thune_a',
              text: 'Có vài tin mới',
              sentAtLabel: '3 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Có vài tin mới',
          lastMessageTime: '3 ngày',
          unreadCount: 7,
        ),
        MessageConversation(
          id: 'group_unread',
          type: MessageConversationType.group,
          title: 'Đà Lạt ơi',
          linkedItineraryId: 'trip_da_lat_member',
          participants: [_me, _chi, _thuneA, _thanh, _trongBui],
          messages: const [
            MessageItem(
              id: 'gu_1',
              senderId: 'me',
              text: 'This is the main chat template',
              sentAtLabel: '18:20',
              dateLabel: '18:20, 2 tháng 8',
            ),
            MessageItem(
              id: 'gu_2',
              senderId: 'thune_a',
              text: 'Oh?',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'gu_3',
              senderId: 'thune_a',
              text: 'Cool',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'gu_4',
              senderId: 'thune_a',
              text: 'How does it work?',
              sentAtLabel: '18:22',
            ),
            MessageItem(
              id: 'gu_5',
              senderId: 'me',
              text:
                  'You just edit any text to type in the conversation you want to show, and delete any bubbles you don’t want to use',
              sentAtLabel: '18:20',
              dateLabel: '18:20, TH 5',
            ),
            MessageItem(
              id: 'gu_6',
              senderId: 'me',
              text: 'Boom!',
              sentAtLabel: '18:21',
            ),
            MessageItem(
              id: 'gu_7',
              senderId: 'chi',
              text: 'Oh?',
              sentAtLabel: '18:22',
              readByCurrentUser: false,
            ),
            MessageItem(
              id: 'gu_8',
              senderId: 'chi',
              text: 'How does it work?',
              sentAtLabel: '18:23',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'chi',
          lastMessageText: 'How does it work?',
          lastMessageTime: '3 ngày',
          unreadCount: 8,
          activityLabel: 'Hoạt động 2 giờ trước',
          mediaAssets: const [
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
          ],
          links: const ['Tên đường link'],
        ),
        MessageConversation(
          id: 'group_cover_read',
          type: MessageConversationType.group,
          title: 'Đà Lạt ơi',
          coverAsset: 'assets/images/checkin.jpg',
          linkedItineraryId: 'trip_da_lat_leader',
          participants: [_meLeader, _chiDeputy, _thuneAMember, _thanh, _trongBui],
          pendingInvites: const [
            MessageGroupInvite(
              contactId: 'dada_1',
              name: 'DaDaDa',
              subtitle: 'Thanh Thúy',
              avatarAsset: 'assets/images/ketban.jpg',
              invitedById: 'me',
            ),
          ],
          messages: const [
            MessageItem(
              id: 'gc_1',
              senderId: 'thune_a',
              text: 'lên plan',
              sentAtLabel: '3 ngày',
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Thune: lên plan',
          lastMessageTime: '3 ngày',
        ),
        MessageConversation(
          id: 'group_deputy_demo',
          type: MessageConversationType.group,
          title: 'Đà Lạt ơi',
          linkedItineraryId: 'trip_da_lat_deputy',
          participants: [_meDeputy, _chi, _thuneAMember, _thanh, _trongBui],
          messages: const [
            MessageItem(
              id: 'gd_1',
              senderId: 'chi',
              text: 'Mình chốt lịch trình nhé',
              sentAtLabel: '2 ngày',
            ),
          ],
          lastSenderId: 'chi',
          lastMessageText: 'ChiThanh: Mình chốt lịch trình nhé',
          lastMessageTime: '2 ngày',
          activityLabel: 'Hoạt động 2 giờ trước',
          mediaAssets: const [
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
            'assets/images/thiennhien.jpg',
          ],
          links: const ['Tên đường link'],
        ),
        MessageConversation(
          id: 'pending_1',
          type: MessageConversationType.direct,
          title: 'Thune',
          participants: [_me, _thuneA],
          messages: const [
            MessageItem(
              id: 'p1_1',
              senderId: 'thune_a',
              text: 'Bạn có thể chấp nhận yêu cầu tin nhắn không?',
              sentAtLabel: '3 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Bạn có thể chấp nhận yêu cầu tin nhắn không?',
          lastMessageTime: '3 ngày',
          unreadCount: 1,
          isPending: true,
        ),
        MessageConversation(
          id: 'pending_2',
          type: MessageConversationType.direct,
          title: 'Thune',
          participants: [_me, _thuneA],
          messages: const [
            MessageItem(
              id: 'p2_1',
              senderId: 'thune_a',
              text: 'Bạn có thể chấp nhận yêu cầu tin nhắn không?',
              sentAtLabel: '3 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'thune_a',
          lastMessageText: 'Bạn có thể chấp nhận yêu cầu tin nhắn không?',
          lastMessageTime: '3 ngày',
          unreadCount: 1,
          isPending: true,
        ),
        MessageConversation(
          id: 'pending_3',
          type: MessageConversationType.direct,
          title: 'DaDaDa',
          participants: [
            _me,
            const MessageParticipant(
              id: 'dada_1',
              name: 'DaDaDa',
              avatarAsset: 'assets/images/ketban.jpg',
            ),
          ],
          messages: const [
            MessageItem(
              id: 'p3_1',
              senderId: 'dada_1',
              text: 'Bạn ơi, mình hỏi chút được không?',
              sentAtLabel: '2 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'dada_1',
          lastMessageText: 'Bạn ơi, mình hỏi chút được không?',
          lastMessageTime: '2 ngày',
          unreadCount: 1,
          isPending: true,
        ),
        MessageConversation(
          id: 'pending_4',
          type: MessageConversationType.direct,
          title: 'Thanh',
          participants: [
            _me,
            const MessageParticipant(
              id: 'thanh_2',
              name: 'Thanh',
              avatarAsset: 'assets/images/survey_beach.jpg',
            ),
          ],
          messages: const [
            MessageItem(
              id: 'p4_1',
              senderId: 'thanh_2',
              text: 'Mình thấy bạn trong chuyến đi Đà Lạt.',
              sentAtLabel: '1 ngày',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'thanh_2',
          lastMessageText: 'Mình thấy bạn trong chuyến đi Đà Lạt.',
          lastMessageTime: '1 ngày',
          unreadCount: 1,
          isPending: true,
        ),
        MessageConversation(
          id: 'pending_5',
          type: MessageConversationType.direct,
          title: 'Trọng Bùi',
          participants: [
            _me,
            const MessageParticipant(
              id: 'trong_bui_2',
              name: 'Trọng Bùi',
              nickname: 'Buiji',
              avatarAsset: 'assets/images/survey_resort.jpg',
            ),
          ],
          messages: const [
            MessageItem(
              id: 'p5_1',
              senderId: 'trong_bui_2',
              text: 'Cho mình xin thông tin lịch trình với.',
              sentAtLabel: '5 giờ',
              readByCurrentUser: false,
            ),
          ],
          lastSenderId: 'trong_bui_2',
          lastMessageText: 'Cho mình xin thông tin lịch trình với.',
          lastMessageTime: '5 giờ',
          unreadCount: 1,
          isPending: true,
        ),
      ]);
  }

  @override
  List<MessageConversation> get mainConversations =>
      List.unmodifiable(_items.where((item) => !item.isPending));

  @override
  List<MessageConversation> get pendingConversations =>
      List.unmodifiable(_items.where((item) => item.isPending));

  @override
  List<MessageContact> get contacts => List.unmodifiable(_contacts);

  @override
  List<MessageItinerary> get itineraries => List.unmodifiable(_itineraries);

  @override
  List<MessageItinerary> get inviteableItineraries => List.unmodifiable(
        _itineraries.where((item) => item.canInviteMembers),
      );

  @override
  MessageConversation? conversation(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  MessageItinerary? linkedGroupItinerary(String conversationId) {
    final item = conversation(conversationId);
    final itineraryId = item?.linkedItineraryId;
    if (itineraryId == null) return null;

    for (final itinerary in _itineraries) {
      if (itinerary.id == itineraryId) return itinerary;
    }
    return null;
  }

  @override
  MessageGroupRole groupRole(String conversationId) {
    final item = conversation(conversationId);
    if (item == null || !item.isGroup) return MessageGroupRole.member;
    return item.roleOf(currentUserId);
  }

  @override
  List<MessageGroupInvite> pendingGroupInvites(String conversationId) {
    final item = conversation(conversationId);
    if (item == null || !item.isGroup) return const [];
    return List.unmodifiable(item.pendingInvites);
  }

  @override
  List<MessageContact> searchContacts(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return contacts;

    return _contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(normalized) ||
              contact.subtitle.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  List<MessageSearchResult> searchMessages(
    String conversationId,
    String query,
  ) {
    final target = conversation(conversationId);
    if (target == null) return const [];

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final participantById = <String, MessageParticipant>{
      for (final participant in target.participants) participant.id: participant,
    };

    return target.messages
        .where((message) => message.text.toLowerCase().contains(normalized))
        .map(
          (message) => MessageSearchResult(
            messageId: message.id,
            senderName:
                participantById[message.senderId]?.displayName ?? 'Người dùng',
            text: message.text,
          ),
        )
        .toList(growable: false);
  }

  @override
  String openOrCreateDirectConversation(String contactId) {
    MessageConversation? pendingMatch;

    for (final item in _items) {
      if (item.type != MessageConversationType.direct) continue;
      if (!item.participants.any((p) => p.id == contactId)) continue;

      // Ưu tiên chat đã được chấp nhận nếu tồn tại.
      if (!item.isPending) return item.id;

      // Nếu chỉ có request thì mở chính request đó, tuyệt đối không tạo thêm
      // một direct conversation mới cho cùng người dùng.
      pendingMatch ??= item;
    }

    if (pendingMatch != null) return pendingMatch.id;

    final contact = _contacts.firstWhere((item) => item.id == contactId);
    final id = 'direct_${contact.id}_${DateTime.now().millisecondsSinceEpoch}';

    _items.insert(
      0,
      MessageConversation(
        id: id,
        type: MessageConversationType.direct,
        title: contact.name,
        participants: [
          _me,
          MessageParticipant(
            id: contact.id,
            name: contact.name,
            avatarAsset: contact.avatarAsset,
          ),
        ],
        messages: const [],
        lastSenderId: '',
        lastMessageText: '',
        lastMessageTime: '',
      ),
    );

    notifyListeners();
    return id;
  }

  @override
  void markRead(String conversationId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    if (item.unreadCount == 0) return;

    _items[index] = item.copyWith(unreadCount: 0);
    notifyListeners();
  }

  @override
  void acceptPending(Iterable<String> conversationIds) {
    final ids = conversationIds.toSet();

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (!ids.contains(item.id)) continue;
      if (!item.isPending || item.isBlocked) continue;

      _items[i] = item.copyWith(
        isPending: false,
        unreadCount: 0,
      );
    }

    notifyListeners();
  }

  @override
  void deletePending(Iterable<String> conversationIds) {
    final ids = conversationIds.toSet();
    _items.removeWhere(
      (item) => item.isPending && ids.contains(item.id),
    );
    notifyListeners();
  }

  @override
  void blockConversation(String conversationId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];

    // Group không dùng block theo flow direct-message này.
    if (item.isGroup || item.isBlocked) return;

    // Cả direct chat đã chấp nhận và Tin nhắn đang chờ đều được GIỮ LẠI.
    // Block chỉ đổi trạng thái, không xoá conversation/lịch sử/request.
    // Vì vậy request chưa chấp nhận vẫn có thể mở lại và "Bỏ chặn".
    _items[index] = item.copyWith(
      isBlocked: true,
      unreadCount: 0,
    );
    notifyListeners();
  }

  @override
  void unblockConversation(String conversationId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    if (item.isGroup || !item.isBlocked) return;

    // Cho phép unblock cả direct chat bình thường lẫn message request.
    _items[index] = item.copyWith(
      isBlocked: false,
    );
    notifyListeners();
  }

  @override
  void leaveGroup(String conversationId) {
    final item = conversation(conversationId);
    if (item == null || !item.isGroup) return;

    // Trưởng nhóm là chủ lịch trình nên không được rời nhóm.
    final role = item.roleOf(currentUserId);
    if (role == MessageGroupRole.leader) return;

    // Mock-state: rời nhóm = conversation + group itinerary không còn thuộc
    // phạm vi của user hiện tại. Đây chỉ là xoá khỏi local user-view, không
    // đại diện cho việc xoá lịch trình khỏi backend của các thành viên khác.
    final itineraryId = item.linkedItineraryId;
    _items.removeWhere((candidate) => candidate.id == conversationId);
    if (itineraryId != null) {
      _itineraries.removeWhere((itinerary) => itinerary.id == itineraryId);
    }
    notifyListeners();
  }

  @override
  void deleteGroupAndItinerary(String conversationId) {
    final item = conversation(conversationId);
    if (item == null || !item.isGroup) return;
    if (item.roleOf(currentUserId) != MessageGroupRole.leader) return;

    final itineraryId = item.linkedItineraryId;
    _items.removeWhere((candidate) => candidate.id == conversationId);
    if (itineraryId != null) {
      _itineraries.removeWhere((itinerary) => itinerary.id == itineraryId);
    }
    notifyListeners();
  }

  @override
  void renameGroup(String conversationId, String name) {
    final value = name.trim();
    if (value.isEmpty) return;

    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup) return;

    final role = item.roleOf(currentUserId);
    if (role != MessageGroupRole.leader &&
        role != MessageGroupRole.deputy) {
      return;
    }

    _items[index] = item.copyWith(title: value);
    notifyListeners();
  }

  @override
  void inviteGroupMembers(
    String conversationId,
    Iterable<String> contactIds,
  ) {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup) return;

    final role = item.roleOf(currentUserId);
    if (role != MessageGroupRole.leader &&
        role != MessageGroupRole.deputy) {
      return;
    }

    final memberIds = item.participants.map((e) => e.id).toSet();
    final invites = [...item.pendingInvites];
    final pendingIds = invites.map((e) => e.contactId).toSet();

    for (final id in contactIds.toSet()) {
      if (memberIds.contains(id) || pendingIds.contains(id)) continue;
      final matches = _contacts.where((contact) => contact.id == id);
      if (matches.isEmpty) continue;
      final contact = matches.first;

      invites.add(
        MessageGroupInvite(
          contactId: contact.id,
          name: contact.name,
          subtitle: contact.subtitle,
          avatarAsset: contact.avatarAsset,
          invitedById: currentUserId,
        ),
      );
      pendingIds.add(id);
    }

    _items[index] = item.copyWith(pendingInvites: invites);
    notifyListeners();
  }

  @override
  void cancelGroupInvite(
      String conversationId,
      String contactId,
      ) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    if (!item.isGroup) return;

    final role = item.roleOf(currentUserId);

    if (role != MessageGroupRole.leader &&
        role != MessageGroupRole.deputy) {
      return;
    }

    _items[index] = item.copyWith(
      pendingInvites: item.pendingInvites
          .where(
            (invite) => invite.contactId != contactId,
      )
          .toList(growable: false),
    );

    notifyListeners();
  }

  @override
  void removeGroupMembers(
    String conversationId,
    Iterable<String> participantIds,
  ) {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup) return;

    final actorRole = item.roleOf(currentUserId);
    if (actorRole == MessageGroupRole.member) return;

    final ids = participantIds.toSet();
    final participants = item.participants.where((participant) {
      if (!ids.contains(participant.id)) return true;
      if (participant.id == currentUserId) return true;
      if (participant.role == MessageGroupRole.leader) return true;

      if (actorRole == MessageGroupRole.deputy) {
        return participant.role != MessageGroupRole.member;
      }

      return false;
    }).toList(growable: false);

    _items[index] = item.copyWith(participants: participants);
    notifyListeners();
  }

  @override
  void promoteGroupMembers(
    String conversationId,
    Iterable<String> participantIds,
  ) {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup ||
        item.roleOf(currentUserId) != MessageGroupRole.leader) {
      return;
    }

    final ids = participantIds.toSet();
    final participants = item.participants.map((participant) {
      if (ids.contains(participant.id) &&
          participant.id != currentUserId &&
          participant.role == MessageGroupRole.member) {
        return participant.copyWith(role: MessageGroupRole.deputy);
      }
      return participant;
    }).toList(growable: false);

    _items[index] = item.copyWith(participants: participants);
    notifyListeners();
  }

  @override
  void revokeGroupDeputy(String conversationId, String participantId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup ||
        item.roleOf(currentUserId) != MessageGroupRole.leader) {
      return;
    }

    final participants = item.participants.map((participant) {
      if (participant.id == participantId &&
          participant.id != currentUserId &&
          participant.role == MessageGroupRole.deputy) {
        return participant.copyWith(role: MessageGroupRole.member);
      }
      return participant;
    }).toList(growable: false);

    _items[index] = item.copyWith(participants: participants);
    notifyListeners();
  }

  @override
  void toggleMute(String conversationId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    _items[index] = item.copyWith(isMuted: !item.isMuted);
    notifyListeners();
  }

  @override
  void setNickname({
    required String conversationId,
    required String participantId,
    String? nickname,
  }) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    final trimmed = nickname?.trim();

    final participants = item.participants
        .map(
          (participant) => participant.id == participantId
              ? participant.copyWith(
                  nickname: trimmed,
                  clearNickname: trimmed == null || trimmed.isEmpty,
                )
              : participant,
        )
        .toList(growable: false);

    _items[index] = item.copyWith(participants: participants);
    notifyListeners();
  }

  @override
  void sendText({
    required String conversationId,
    required String text,
  }) {
    final value = text.trim();
    if (value.isEmpty) return;

    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];

    // Direct chat bị chặn không được gửi tin nhắn mới.
    if (!item.isGroup && item.isBlocked) return;

    final message = MessageItem(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      senderId: currentUserId,
      text: value,
      sentAtLabel: 'Bây giờ',
    );

    _items[index] = item.copyWith(
      messages: [...item.messages, message],
      lastSenderId: currentUserId,
      lastMessageText: value,
      lastMessageTime: 'Bây giờ',
      unreadCount: 0,
    );

    notifyListeners();
  }

  @override
  void invitePeerToItinerary({
    required String conversationId,
    required String itineraryId,
  }) {
    final conversation = this.conversation(conversationId);

    if (conversation == null ||
        conversation.isGroup ||
        conversation.isPending ||
        conversation.isBlocked) {
      return;
    }

    MessageParticipant? peer;
    for (final participant in conversation.participants) {
      if (participant.id != currentUserId) {
        peer = participant;
        break;
      }
    }

    if (peer == null) return;

    MessageItinerary? itinerary;
    for (final item in _itineraries) {
      if (item.id == itineraryId) {
        itinerary = item;
        break;
      }
    }

    if (itinerary == null || !itinerary.canInviteMembers) return;

    // Demo UI: đây chỉ là pending invitation.
    // Không tăng memberCount cho tới khi người nhận accept ở backend thật.
    final inviteKey = '$itineraryId:${peer.id}';
    if (!_pendingDirectItineraryInvites.add(inviteKey)) return;

    notifyListeners();
  }

  int _indexOf(String id) => _items.indexWhere((item) => item.id == id);
}

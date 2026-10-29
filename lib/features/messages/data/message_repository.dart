import 'dart:async';
import '../../../core/services/content_access_changes.dart';

import 'package:flutter/foundation.dart';
import '../../posts/data/post_repository.dart' show newPostRequestId;

import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../map/state/map_ui_session.dart';
import '../../trip/data/trip_repository.dart';
import '../models/message_models.dart';

abstract class MessageRepository extends ChangeNotifier {
  Future<void> sendTextConfirmed({
    required String conversationId,
    required String text,
  }) async => sendText(conversationId: conversationId, text: text);
  Future<void> acceptPendingConfirmed(String id) async => acceptPending([id]);
  Future<void> deletePendingConfirmed(String id) async => deletePending([id]);
  void discardDraft(String id) {}
  String get currentUserId;
  String get currentUserName;

  List<MessageConversation> get mainConversations;
  List<MessageConversation> get pendingConversations;
  bool get hasUnread => [
    ...mainConversations,
    ...pendingConversations,
  ].any((item) => item.unreadCount > 0);
  List<MessageContact> get contacts;
  List<MessageItinerary> get itineraries;

  /// Chỉ các lịch trình current user có quyền mời thêm thành viên.
  List<MessageItinerary> get inviteableItineraries;

  Future<void> refresh();
  void forgetTripMembership(String tripId) {}
  MessageConversation? conversation(String id);
  MessageItinerary? linkedGroupItinerary(String conversationId);
  MessageGroupRole groupRole(String conversationId);
  List<MessageContact> groupInviteCandidates(
    String conversationId,
    String query,
  );
  List<MessageGroupInvite> pendingGroupInvites(String conversationId);
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(
    String conversationId,
  );
  List<MessageContact> searchContacts(String query);
  Future<List<MessageContact>> fetchContactSuggestions(String query);
  List<MessageSearchResult> searchMessages(String conversationId, String query);
  String openOrCreateDirectConversation(String contactId);

  void markRead(String conversationId);
  void acceptPending(Iterable<String> conversationIds);
  void deletePending(Iterable<String> conversationIds);
  void blockConversation(String conversationId);
  void unblockConversation(String conversationId);
  Future<void> leaveGroup(String conversationId);
  Future<void> deleteGroupAndItinerary(String conversationId);
  Future<void> transferGroupLeader(
    String conversationId,
    String targetUserId,
  ) => Future.error(UnsupportedError('Chuyển trưởng nhóm chưa khả dụng.'));
  void renameGroup(String conversationId, String name);
  Future<void> inviteGroupMembers(
    String conversationId,
    Iterable<String> contactIds,
  );
  Future<void> cancelGroupInvite(String conversationId, String contactId);
  Future<void> removeGroupMembers(
    String conversationId,
    Iterable<String> participantIds,
  );
  void toggleMute(String conversationId);
  void setNickname({
    required String conversationId,
    required String participantId,
    String? nickname,
  });
  void sendText({required String conversationId, required String text});
  Future<void> invitePeerToItinerary({
    required String conversationId,
    required String itineraryId,
  });
}

class RealDirectMessageRepository extends MessageRepository {
  RealDirectMessageRepository({AuthService? auth, RealTripRepository? trips})
    : _auth = auth ?? AuthService.instance,
      _trips =
          trips ??
          (auth == null
              ? RealTripRepository.instance
              : RealTripRepository(auth: auth)) {
    _auth.addListener(_handleAuthChanged);
    ContentAccessChanges.revision.addListener(_accessChanged);
    unawaited(refresh());
  }

  static final RealDirectMessageRepository instance =
      RealDirectMessageRepository();
  final AuthService _auth;
  final RealTripRepository _trips;

  final List<MessageConversation> _items = <MessageConversation>[];
  final List<MessageContact> _contacts = <MessageContact>[];
  final List<MessageItinerary> _itineraries = <MessageItinerary>[];
  final Map<String, String> _aliases = <String, String>{};
  final Map<String, Future<void>> _detailLoads = <String, Future<void>>{};
  final Set<String> _detailAttempted = <String>{};
  final Map<String, Future<void>> _opening = {};
  final Map<String, ({String text, String requestId, bool first})>
  _sendAttempts = {};
  final Set<String> _sending = {};
  String? _error;
  bool _loading = false;
  int _membershipRevision = 0;
  int _sessionRevision = 0;
  int _inboxRevision = 0;

  bool get loading => _loading;
  String? get error => _error;

  int _invalidateReads() {
    _detailLoads.clear();
    _detailAttempted.clear();
    _loading = false;
    return ++_membershipRevision;
  }

  @override
  String get currentUserId {
    final user = _auth.user;
    final id = _text(user?['id']);
    return id.isEmpty ? _text(user?['userId']) : id;
  }

  @override
  String get currentUserName {
    final user = _auth.user;
    final displayName = _text(user?['displayName']);
    if (displayName.isNotEmpty) return displayName;
    final fullName = _text(user?['fullName']);
    if (fullName.isNotEmpty) return fullName;
    final nickname = _text(user?['nickname']);
    return nickname.isEmpty ? 'GoMate' : nickname;
  }

  @override
  List<MessageConversation> get mainConversations => List.unmodifiable(
    _items.where((item) => !item.isPending && !item.isDraft),
  );

  @override
  List<MessageConversation> get pendingConversations =>
      List.unmodifiable(_items.where((item) => item.isIncomingRequest));

  @override
  List<MessageContact> get contacts => List.unmodifiable(_contacts);

  @override
  List<MessageItinerary> get itineraries => List.unmodifiable(_itineraries);

  @override
  List<MessageItinerary> get inviteableItineraries => _itineraries
      .where((item) => item.canInviteMembers)
      .toList(growable: false);

  @override
  Future<void> refresh() async {
    if (!_auth.signedIn) return;
    final revision = _invalidateReads();
    final inboxRevision = _inboxRevision;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final conversations = await _auth.requestJson('GET', '/conversations');
      final pending = await _auth.requestJson('GET', '/message-requests');
      if (revision != _membershipRevision || inboxRevision != _inboxRevision) {
        return;
      }
      final drafts = _items.where((item) => item.isDraft).toList();
      _items
        ..clear()
        ..addAll([
          ..._asList(conversations).map(_conversationFromSummary),
          ..._asList(pending).map(_conversationFromSummary),
          ...drafts,
        ]);
      final trips = await _auth.requestJson('GET', '/trips');
      if (revision != _membershipRevision) return;
      _itineraries
        ..clear()
        ..addAll(
          _asList(trips).whereType<Map>().map(
            (trip) => MessageItinerary(
              id: trip['id'] as String,
              title: trip['title'] as String,
              dateRange: '${trip['startDate']} - ${trip['endDate']}',
              summary: '${trip['stopCount']} địa điểm',
              imageAsset: 'assets/images/home_dalat.jpg',
              memberCount: (trip['memberCount'] as num).toInt(),
              canInviteMembers:
                  trip['currentUserRole'] == 'LEADER' &&
                  trip['status'] != 'COMPLETED' &&
                  trip['status'] != 'CANCELLED',
            ),
          ),
        );
    } catch (error) {
      _error = error.toString();
    } finally {
      if (revision == _membershipRevision) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchContactsFromApi(String query) async {
    await fetchContactSuggestions(query);
  }

  @override
  Future<List<MessageContact>> fetchContactSuggestions(String query) async {
    final q = query.trim();
    try {
      final uri = Uri(
        path: '/users/search',
        queryParameters: <String, String>{'q': q, 'page': '0', 'size': '20'},
      );
      final response = await _auth.request('GET', uri.toString());
      final contacts = _asList(response['items'])
          .map(_contactFromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      _contacts
        ..clear()
        ..addAll(contacts);
      notifyListeners();
      return contacts;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return const <MessageContact>[];
    }
  }

  @override
  MessageConversation? conversation(String id) {
    final resolvedId = _resolve(id);
    final index = _indexOf(resolvedId);
    if (index < 0) return null;
    final item = _items[index];
    // Empty chats are valid loaded results. Retry failures on explicit refresh/read,
    // never on every build/listener notification.
    if (!_loading && !item.isDraft && !_detailAttempted.contains(resolvedId)) {
      unawaited(_loadDetail(resolvedId));
    }
    return item;
  }

  @override
  MessageItinerary? linkedGroupItinerary(String conversationId) {
    final conversation = this.conversation(conversationId);
    if (conversation == null || !conversation.isGroup) return null;
    final tripId = conversation.linkedItineraryId;
    if (tripId == null || tripId.trim().isEmpty) return null;
    return MessageItinerary(
      id: tripId,
      title: conversation.title,
      dateRange: '',
      summary: '${conversation.participants.length} thành viên',
      imageAsset: conversation.coverAsset ?? 'assets/images/home_dalat.jpg',
      memberCount: conversation.participants.length,
    );
  }

  @override
  MessageGroupRole groupRole(String conversationId) =>
      conversation(conversationId)?.roleOf(currentUserId) ??
      MessageGroupRole.member;

  @override
  List<MessageContact> groupInviteCandidates(
    String conversationId,
    String query,
  ) => const <MessageContact>[];

  @override
  List<MessageGroupInvite> pendingGroupInvites(String conversationId) =>
      const <MessageGroupInvite>[];

  @override
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(
    String conversationId,
  ) async {
    final tripId = conversation(_resolve(conversationId))?.linkedItineraryId;
    if (tripId == null) throw StateError('Không tìm thấy lịch trình của nhóm.');
    final trip = await _trips.detail(tripId);
    return trip.pendingInvitees
        .map(
          (person) => MessageGroupInvite(
            contactId: person.id,
            name: person.name,
            subtitle: person.subtitle,
            avatarAsset: person.avatarAsset,
            invitedById: '',
          ),
        )
        .toList(growable: false);
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
    if (target == null) return const <MessageSearchResult>[];
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const <MessageSearchResult>[];
    return target.messages
        .where((message) => message.text.toLowerCase().contains(normalized))
        .map(
          (message) => MessageSearchResult(
            messageId: message.id,
            senderName: message.senderId == currentUserId
                ? currentUserName
                : target.title,
            text: message.text,
          ),
        )
        .toList(growable: false);
  }

  @override
  String openOrCreateDirectConversation(String contactId) {
    return openOrCreateDirectConversationWithPeer(contactId: contactId);
  }

  String openOrCreateDirectConversationWithPeer({
    required String contactId,
    String? name,
    String? subtitle,
    String? avatarUrl,
  }) {
    final existing = _items.where((item) {
      if (item.type != MessageConversationType.direct) return false;
      return item.participants.any((p) => p.id == contactId);
    });
    for (final item in existing) {
      if (item.isDraft) return item.id;
    }

    MessageContact? contact;
    for (final item in _contacts) {
      if (item.id == contactId) {
        contact = item;
        break;
      }
    }
    contact ??= MessageContact(
      id: contactId,
      name: name?.trim().isNotEmpty == true ? name!.trim() : 'Người dùng',
      subtitle: subtitle?.trim().isNotEmpty == true ? subtitle!.trim() : '',
      avatarAsset: avatarUrl?.trim().isNotEmpty == true
          ? avatarUrl!.trim()
          : null,
    );
    final temporaryId = 'opening_${newPostRequestId()}';
    _items.insert(
      0,
      MessageConversation(
        id: temporaryId,
        type: MessageConversationType.direct,
        title: contact.name,
        participants: [
          _me(),
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
        isDraft: true,
        isRequester: true,
      ),
    );
    notifyListeners();
    _opening[temporaryId] = _openDirect(contactId, temporaryId);
    return temporaryId;
  }

  @override
  void markRead(String conversationId) {
    final resolvedId = _resolve(conversationId);
    if (resolvedId.startsWith('opening_')) return;
    final index = _indexOf(resolvedId);
    if (index >= 0 && _items[index].unreadCount > 0) {
      _items[index] = _items[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
    unawaited(
      _auth
          .request('POST', '/conversations/$resolvedId/read')
          .catchError((_) => <String, dynamic>{}),
    );
    unawaited(_loadDetail(resolvedId));
  }

  @override
  void acceptPending(Iterable<String> conversationIds) {
    for (final id in conversationIds.toSet()) {
      unawaited(acceptPendingConfirmed(id).catchError(_setError));
    }
  }

  @override
  void deletePending(Iterable<String> conversationIds) {
    for (final id in conversationIds.toSet()) {
      unawaited(deletePendingConfirmed(id).catchError(_setError));
    }
  }

  @override
  void blockConversation(String conversationId) {
    unawaited(_toggleBlock(conversationId, true));
  }

  @override
  void unblockConversation(String conversationId) {
    unawaited(_toggleBlock(conversationId, false));
  }

  @override
  Future<void> leaveGroup(String conversationId) async {
    final item = conversation(_resolve(conversationId));
    final tripId = item?.linkedItineraryId;
    if (item == null ||
        !item.isGroup ||
        tripId == null ||
        item.roleOf(currentUserId) == MessageGroupRole.leader) {
      throw StateError('Chỉ thành viên được rời lịch trình nhóm.');
    }
    await _trips.leave(tripId);
    forgetTripMembership(tripId);
    GoMateMapUiSession.removeTrip(tripId);
    await refresh();
  }

  @override
  void forgetTripMembership(String tripId) {
    _invalidateReads();
    _items.removeWhere(
      (entry) => entry.isGroup && entry.linkedItineraryId == tripId,
    );
    _itineraries.removeWhere((entry) => entry.id == tripId);
    notifyListeners();
  }

  @override
  Future<void> deleteGroupAndItinerary(String conversationId) async {
    final item = conversation(_resolve(conversationId));
    final tripId = item?.linkedItineraryId;
    if (item == null ||
        !item.isGroup ||
        tripId == null ||
        item.roleOf(currentUserId) != MessageGroupRole.leader) {
      throw StateError('Chỉ nhóm trưởng được xóa lịch trình nhóm.');
    }
    await _trips.delete(tripId);
    forgetTripMembership(tripId);
    GoMateMapUiSession.removeTrip(tripId);
    await refresh();
  }

  @override
  Future<void> transferGroupLeader(
    String conversationId,
    String targetUserId,
  ) async {
    final item = conversation(_resolve(conversationId));
    final tripId = item?.linkedItineraryId;
    if (item == null ||
        !item.isGroup ||
        tripId == null ||
        item.roleOf(currentUserId) != MessageGroupRole.leader ||
        targetUserId == currentUserId ||
        !item.participants.any(
          (p) => p.id == targetUserId && p.role == MessageGroupRole.member,
        )) {
      throw StateError('Thành viên nhận quyền không hợp lệ.');
    }
    final trip = await _trips.transferLeader(tripId, targetUserId);
    _invalidateReads();
    GoMateMapUiSession.updateTrip(trip);
    final index = _indexOf(item.id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        participants: trip.members
            .map(
              (m) => MessageParticipant(
                id: m.id,
                name: m.name,
                avatarAsset: m.avatarAsset,
                role: m.isOwner
                    ? MessageGroupRole.leader
                    : MessageGroupRole.member,
              ),
            )
            .toList(),
      );
    }
    notifyListeners();
    await refresh();
  }

  @override
  void renameGroup(String conversationId, String name) {
    final value = name.trim();
    if (value.isEmpty) return;
    final resolvedId = _resolve(conversationId);
    unawaited(
      _auth
          .request(
            'PATCH',
            '/conversations/$resolvedId/name',
            body: {'name': value},
          )
          .then((response) {
            final index = _indexOf(resolvedId);
            if (index >= 0) _items[index] = _conversationFromSummary(response);
            notifyListeners();
          })
          .catchError((error) {
            _setError(error);
            return null;
          }),
    );
  }

  @override
  Future<void> inviteGroupMembers(
    String conversationId,
    Iterable<String> contactIds,
  ) async {
    final resolvedId = _resolve(conversationId);
    final conversation = this.conversation(resolvedId);
    final tripId = conversation?.linkedItineraryId;
    final ids = contactIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (tripId == null || tripId.trim().isEmpty || ids.isEmpty) {
      throw StateError('Không xác định được lịch trình để gửi lời mời.');
    }
    await _auth.request(
      'POST',
      '/trips/$tripId/members',
      body: {'selectedMemberIds': ids},
    );
    await refresh();
  }

  @override
  Future<void> cancelGroupInvite(
    String conversationId,
    String contactId,
  ) async {
    final item = conversation(_resolve(conversationId));
    final tripId = item?.linkedItineraryId;
    if (item == null ||
        tripId == null ||
        item.roleOf(currentUserId) != MessageGroupRole.leader) {
      throw StateError('Chỉ nhóm trưởng được hủy lời mời.');
    }
    final trip = await _trips.detail(tripId);
    final pending = trip.pendingInvitees
        .where((person) => person.id == contactId)
        .firstOrNull;
    final invitationId = pending?.invitationId;
    if (invitationId == null || invitationId.isEmpty) {
      throw StateError('Lời mời không còn ở trạng thái chờ.');
    }
    await _trips.cancelInvitation(tripId, invitationId);
    await refresh();
  }

  @override
  Future<void> removeGroupMembers(
    String conversationId,
    Iterable<String> participantIds,
  ) async {
    final item = conversation(_resolve(conversationId));
    final tripId = item?.linkedItineraryId;
    if (item == null ||
        !item.isGroup ||
        tripId == null ||
        item.roleOf(currentUserId) != MessageGroupRole.leader) {
      throw StateError('Chỉ nhóm trưởng được xóa thành viên.');
    }
    final ids = participantIds.toSet();
    if (ids.any(
      (id) =>
          id == currentUserId ||
          !item.participants.any(
            (p) => p.id == id && p.role == MessageGroupRole.member,
          ),
    )) {
      throw StateError('Thành viên được chọn không hợp lệ.');
    }
    try {
      for (final id in ids) {
        final trip = await _trips.removeMember(tripId, id);
        _invalidateReads();
        GoMateMapUiSession.updateTrip(trip);
        final index = _indexOf(item.id);
        if (index >= 0) {
          if (!trip.isGroup) {
            _items.removeAt(index);
          } else {
            _items[index] = _items[index].copyWith(
              participants: trip.members
                  .map(
                    (m) => MessageParticipant(
                      id: m.id,
                      name: m.name,
                      avatarAsset: m.avatarAsset,
                      role: m.isOwner
                          ? MessageGroupRole.leader
                          : MessageGroupRole.member,
                    ),
                  )
                  .toList(),
            );
          }
        }
        notifyListeners();
      }
    } finally {
      // A bulk UI selection uses per-member atomic APIs; reconcile partial ACKs too.
      await refresh();
    }
  }

  @override
  void toggleMute(String conversationId) {
    final item = conversation(conversationId);
    if (item == null) return;
    final next = !item.isMuted;
    final resolvedId = _resolve(conversationId);
    unawaited(
      _auth
          .request(next ? 'POST' : 'DELETE', '/conversations/$resolvedId/mute')
          .then((_) {
            final index = _indexOf(resolvedId);
            if (index >= 0) {
              _items[index] = _items[index].copyWith(isMuted: next);
              notifyListeners();
            }
          })
          .catchError((error) {
            _setError(error);
            return null;
          }),
    );
  }

  @override
  void setNickname({
    required String conversationId,
    required String participantId,
    String? nickname,
  }) {}

  @override
  void sendText({required String conversationId, required String text}) {
    unawaited(
      sendTextConfirmed(
        conversationId: conversationId,
        text: text,
      ).catchError(_setError),
    );
  }

  @override
  Future<void> sendTextConfirmed({
    required String conversationId,
    required String text,
  }) async {
    final actor = currentUserId;
    final session = _sessionRevision;
    if (!_sending.add(conversationId))
      throw StateError('Tin nhắn đang được gửi.');
    try {
      await _opening[conversationId];
      if (session != _sessionRevision ||
          actor != currentUserId ||
          !_auth.signedIn)
        throw StateError('Phiên đăng nhập đã thay đổi.');
      var resolvedId = _resolve(conversationId);
      await _detailLoads[resolvedId];
      if (session != _sessionRevision || actor != currentUserId) {
        throw StateError('Phiên đăng nhập đã thay đổi.');
      }
      final index = _indexOf(resolvedId);
      if (index < 0) throw StateError(_error ?? 'Không thể mở đoạn chat.');
      var item = _items[index];
      final value = text.trim();
      final previous = _sendAttempts[conversationId];
      final attempt = previous?.text == value
          ? previous!
          : (text: value, requestId: newPostRequestId(), first: item.isDraft);
      _sendAttempts[conversationId] = attempt;
      final peer = item.participants.firstWhere((p) => p.id != actor);
      final response = await _auth.request(
        'POST',
        attempt.first
            ? '/conversations/direct/messages'
            : '/conversations/$resolvedId/messages',
        body: {
          'text': value,
          'clientRequestId': attempt.requestId,
          if (attempt.first) 'targetUserId': peer.id,
        },
      );
      if (session != _sessionRevision ||
          actor != currentUserId ||
          !_auth.signedIn)
        throw StateError('Phiên đăng nhập đã thay đổi.');
      final message = _messageFromJson(
        attempt.first ? response['message'] : response,
      );
      if (attempt.first) {
        final summary = _conversationFromSummary(response['conversation']);
        _aliases[conversationId] = summary.id;
        _items.removeWhere(
          (entry) => entry.id == resolvedId || entry.id == summary.id,
        );
        item = summary.copyWith(messages: item.messages);
        _items.insert(0, item);
        resolvedId = summary.id;
      }
      final savedIndex = _indexOf(resolvedId);
      if (savedIndex >= 0) {
        item = _items.removeAt(savedIndex);
        _items.insert(
          0,
          item.copyWith(
            messages: [
              ...item.messages.where((m) => m.id != message.id),
              message,
            ],
            lastSenderId: message.senderId,
            lastMessageText: message.text,
            lastMessageTime: 'Bây giờ',
            unreadCount: 0,
          ),
        );
      }
      _inboxRevision++;
      _sendAttempts.remove(conversationId);
      notifyListeners();
    } finally {
      _sending.remove(conversationId);
    }
  }

  @override
  void discardDraft(String id) {
    final resolved = _resolve(id);
    _items.removeWhere((item) => item.id == resolved && item.isDraft);
    _opening.remove(id);
    _sendAttempts.remove(id);
    _aliases.remove(id);
  }

  @override
  Future<void> invitePeerToItinerary({
    required String conversationId,
    required String itineraryId,
  }) async {
    final item = conversation(conversationId);
    if (item == null || item.isGroup || item.isBlocked) {
      throw StateError('Không thể mời từ đoạn chat này.');
    }
    final peer = item.participants
        .where((person) => person.id != currentUserId)
        .firstOrNull;
    if (peer == null) throw StateError('Không tìm thấy người được mời.');
    await _auth.request(
      'POST',
      '/trips/$itineraryId/invitations',
      body: {'inviteeUserId': peer.id},
    );
  }

  Future<void> _openDirect(String contactId, String temporaryId) async {
    final actor = currentUserId;
    final session = _sessionRevision;
    try {
      final response = await _auth.request(
        'POST',
        '/conversations/direct',
        body: {'targetUserId': contactId},
      );
      if (session != _sessionRevision ||
          actor != currentUserId ||
          !_auth.signedIn ||
          _indexOf(temporaryId) < 0)
        return;
      if (response['status'] == 'DRAFT') return;
      final conversation = _conversationFromSummary(response);
      _aliases[temporaryId] = conversation.id;
      final index = _indexOf(temporaryId);
      if (index >= 0) {
        _items[index] = conversation;
      } else {
        _items.insert(0, conversation);
      }
      _items.removeWhere(
        (item) => item.id == conversation.id && !identical(item, conversation),
      );
      notifyListeners();
    } catch (error) {
      if (session != _sessionRevision || actor != currentUserId) return;
      _items.removeWhere((item) => item.id == temporaryId && item.isDraft);
      _setError(error);
    }
  }

  Future<void> _loadDetail(String conversationId) {
    final pending = _detailLoads[conversationId];
    if (pending != null) return pending;
    _detailAttempted.add(conversationId);
    late final Future<void> load;
    load = _fetchDetail(conversationId, _membershipRevision).whenComplete(() {
      if (identical(_detailLoads[conversationId], load)) {
        _detailLoads.remove(conversationId);
      }
    });
    _detailLoads[conversationId] = load;
    return load;
  }

  Future<void> _fetchDetail(String conversationId, int revision) async {
    try {
      final response = await _auth.request(
        'GET',
        '/conversations/$conversationId?limit=50',
      );
      if (revision != _membershipRevision) return;
      final summary = _conversationFromSummary(response['conversation']);
      final messages = _asList(
        response['messages'],
      ).map(_messageFromJson).toList();
      final index = _indexOf(conversationId);
      if (index >= 0) {
        _items[index] = summary.copyWith(messages: messages);
        notifyListeners();
      }
    } catch (error) {
      if (revision != _membershipRevision) return;
      final index = _indexOf(conversationId);
      if (error is ApiException &&
          (error.status == 403 || error.status == 404) &&
          index >= 0 &&
          _items[index].isGroup) {
        final item = _items.removeAt(index);
        _invalidateReads();
        if (item.roleOf(currentUserId) != MessageGroupRole.leader &&
            item.linkedItineraryId != null) {
          // A closed chat is not necessarily lost Trip membership. Refetch Trip
          // authority before discarding readable completion/cancellation history.
          try {
            final trip = await _trips.detail(item.linkedItineraryId!);
            if (revision + 1 != _membershipRevision) return;
            GoMateMapUiSession.updateTrip(trip);
          } on ApiException catch (e) {
            if (revision + 1 != _membershipRevision) return;
            if (e.status == 403 || e.status == 404) {
              _itineraries.removeWhere(
                (trip) => trip.id == item.linkedItineraryId,
              );
              GoMateMapUiSession.removeTrip(item.linkedItineraryId!);
            }
          } catch (_) {
            /* Offline is not proof of lost membership. */
          }
        }
      }
      _setError(error);
    }
  }

  @override
  Future<void> acceptPendingConfirmed(String conversationId) async {
    final actor = currentUserId;
    final session = _sessionRevision;
    final resolvedId = _resolve(conversationId);
    try {
      final response = await _auth.request(
        'POST',
        '/message-requests/$resolvedId/accept',
      );
      if (session != _sessionRevision || actor != currentUserId)
        throw StateError('Phiên đăng nhập đã thay đổi.');
      _invalidateReads();
      final index = _indexOf(resolvedId);
      if (index >= 0) {
        final messages = _items.removeAt(index).messages;
        _items.insert(
          0,
          _conversationFromSummary(response).copyWith(messages: messages),
        );
      }
      notifyListeners();
    } catch (error) {
      _setError(error);
      rethrow;
    }
  }

  @override
  Future<void> deletePendingConfirmed(String conversationId) async {
    final actor = currentUserId;
    final session = _sessionRevision;
    final resolvedId = _resolve(conversationId);
    try {
      await _auth.request('DELETE', '/message-requests/$resolvedId');
      if (session != _sessionRevision || actor != currentUserId)
        throw StateError('Phiên đăng nhập đã thay đổi.');
      _invalidateReads();
      _items.removeWhere((item) => item.id == resolvedId);
      notifyListeners();
    } catch (error) {
      _setError(error);
      rethrow;
    }
  }

  void _accessChanged() {
    _invalidateReads();
    unawaited(refresh());
  }

  Future<void> _toggleBlock(String conversationId, bool blocked) async {
    final session = _auth.sessionGeneration;
    final resolvedId = _resolve(conversationId);
    try {
      final response = await _auth.request(
        blocked ? 'POST' : 'DELETE',
        '/conversations/$resolvedId/block',
      );
      if (session != _auth.sessionGeneration) return;
      final index = _indexOf(resolvedId);
      if (index >= 0) _items[index] = _conversationFromSummary(response);
      ContentAccessChanges.changed();
      notifyListeners();
    } catch (error) {
      _setError(error);
    }
  }

  MessageConversation _conversationFromSummary(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final peer = json['peer'] is Map ? json['peer'] as Map : const {};
    final isGroup = _text(json['type']) == 'GROUP';
    final latest = json['latestMessage'] is Map
        ? json['latestMessage'] as Map
        : null;
    final peerParticipant = MessageParticipant(
      id: _text(peer['userId']),
      name: _text(peer['displayName'], fallback: _text(peer['nickname'])),
      avatarAsset: _nullableText(peer['avatarUrl']),
    );
    final latestMessage = latest == null ? null : _messageFromJson(latest);
    final status = _text(json['status']);
    final members = isGroup
        ? _asList(json['members']).map(_participantFromJson).toList()
        : [_me(), peerParticipant];
    return MessageConversation(
      id: _text(json['conversationId']),
      type: isGroup
          ? MessageConversationType.group
          : MessageConversationType.direct,
      title: isGroup
          ? _text(json['displayName'], fallback: 'Nhóm')
          : peerParticipant.displayName,
      participants: members,
      messages: latestMessage == null ? const [] : [latestMessage],
      lastSenderId: latestMessage?.senderId ?? '',
      lastMessageText: latestMessage?.postId != null
          ? 'Bài viết GoMate'
          : latestMessage?.text ?? '',
      lastMessageTime: _timeLabel(latest?['createdAt'] ?? json['updatedAt']),
      unreadCount: _int(json['unreadCount']),
      isPending: status == 'PENDING',
      isRequester: json['requester'] == true,
      isMuted: json['muted'] == true,
      isBlocked: json['blockedByMe'] == true,
      canSend: json['canSend'] != false,
      canAcceptRequest: json['canAccept'] != false,
      linkedItineraryId: isGroup ? _nullableText(json['linkedTripId']) : null,
    );
  }

  MessageParticipant _participantFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return MessageParticipant(
      id: _text(json['userId']),
      name: _text(json['displayName'], fallback: 'Thành viên'),
      avatarAsset: _nullableText(json['avatarUrl']),
      role: _text(json['role']) == 'LEADER'
          ? MessageGroupRole.leader
          : MessageGroupRole.member,
    );
  }

  MessageContact _contactFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return MessageContact(
      id: _text(json['userId']),
      name: _text(json['displayName'], fallback: _text(json['nickname'])),
      subtitle: _text(json['bio'], fallback: '@${_text(json['nickname'])}'),
      avatarAsset: _nullableText(json['avatarUrl']),
    );
  }

  MessageItem _messageFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return MessageItem(
      postId: json['type'] == 'POST_SHARE' && json['context'] is Map
          ? int.tryParse(json['context']['postId'].toString())
          : null,
      id: _text(json['messageId']),
      senderId: _text(json['senderUserId']),
      text: _text(json['text']),
      sentAtLabel: _timeLabel(json['createdAt']),
    );
  }

  MessageParticipant _me() {
    return MessageParticipant(id: currentUserId, name: currentUserName);
  }

  List<Object?> _asList(Object? value) {
    if (value is List) return value;
    return const <Object?>[];
  }

  int _indexOf(String id) => _items.indexWhere((item) => item.id == id);

  String _resolve(String id) => _aliases[id] ?? id;

  int _int(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _nullableText(Object? value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  String _timeLabel(Object? value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final delta = DateTime.now().difference(parsed.toLocal());
    if (delta.inMinutes < 1) return 'Bây giờ';
    if (delta.inHours < 1) return '${delta.inMinutes} phút';
    if (delta.inDays < 1) return '${delta.inHours} giờ';
    return '${delta.inDays} ngày';
  }

  void _handleAuthChanged() {
    if (!_auth.signedIn) {
      _sessionRevision++;
      _invalidateReads();
      _aliases.clear();
      _opening.clear();
      _sendAttempts.clear();
      _items.clear();
      _contacts.clear();
      _itineraries.clear();
      notifyListeners();
      return;
    }
    if (_items.isEmpty && !_loading) unawaited(refresh());
  }

  void _setError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    _invalidateReads();
    super.dispose();
  }
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
  /// Key = `itineraryId:inviteeUserId`.
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
      id: 'trip_da_lat_member_view',
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

  MessageParticipant get _me =>
      const MessageParticipant(id: 'me', name: 'Thune');

  MessageParticipant get _meLeader => const MessageParticipant(
    id: 'me',
    name: 'Thune',
    role: MessageGroupRole.leader,
  );

  MessageParticipant get _meMember =>
      const MessageParticipant(id: 'me', name: 'Thune');

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
          participants: [
            _meLeader,
            _chiMember,
            _thuneAMember,
            _thanh,
            _trongBui,
          ],
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
          id: 'group_member_demo',
          type: MessageConversationType.group,
          title: 'Đà Lạt ơi',
          linkedItineraryId: 'trip_da_lat_member_view',
          participants: [_meMember, _chi, _thuneAMember, _thanh, _trongBui],
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
  Future<void> refresh() async {}

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
  List<MessageItinerary> get inviteableItineraries =>
      List.unmodifiable(_itineraries.where((item) => item.canInviteMembers));

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
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(
    String conversationId,
  ) async => pendingGroupInvites(conversationId);

  @override
  List<MessageContact> groupInviteCandidates(
    String conversationId,
    String query,
  ) {
    final item = conversation(conversationId);
    if (item == null || !item.isGroup) return const [];

    final memberIds = item.participants.map((e) => e.id).toSet();
    final pendingIds = item.pendingInvites.map((e) => e.contactId).toSet();
    final normalized = query.trim().toLowerCase();

    final result = _contacts
        .where((contact) {
          if (memberIds.contains(contact.id)) return false;
          if (normalized.isEmpty) return true;
          return contact.name.toLowerCase().contains(normalized) ||
              contact.subtitle.toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    result.sort((a, b) {
      final ap = pendingIds.contains(a.id);
      final bp = pendingIds.contains(b.id);
      if (ap == bp) return 0;
      return ap ? -1 : 1;
    });

    return result;
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
  Future<List<MessageContact>> fetchContactSuggestions(String query) async {
    return searchContacts(query);
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
      for (final participant in target.participants)
        participant.id: participant,
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

      _items[i] = item.copyWith(isPending: false, unreadCount: 0);
    }

    notifyListeners();
  }

  @override
  void deletePending(Iterable<String> conversationIds) {
    final ids = conversationIds.toSet();
    _items.removeWhere((item) => item.isPending && ids.contains(item.id));
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
    _items[index] = item.copyWith(isBlocked: true, unreadCount: 0);
    notifyListeners();
  }

  @override
  void unblockConversation(String conversationId) {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    if (item.isGroup || !item.isBlocked) return;

    // Cho phép unblock cả direct chat bình thường lẫn message request.
    _items[index] = item.copyWith(isBlocked: false);
    notifyListeners();
  }

  @override
  Future<void> leaveGroup(String conversationId) async {
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
  Future<void> deleteGroupAndItinerary(String conversationId) async {
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
    if (role != MessageGroupRole.leader) {
      return;
    }

    _items[index] = item.copyWith(title: value);
    notifyListeners();
  }

  @override
  Future<void> inviteGroupMembers(
    String conversationId,
    Iterable<String> contactIds,
  ) async {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup) return;

    final role = item.roleOf(currentUserId);
    if (role != MessageGroupRole.leader) {
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
  Future<void> cancelGroupInvite(
    String conversationId,
    String contactId,
  ) async {
    final index = _indexOf(conversationId);
    if (index < 0) return;

    final item = _items[index];
    if (!item.isGroup) return;

    final role = item.roleOf(currentUserId);

    if (role != MessageGroupRole.leader) {
      return;
    }

    _items[index] = item.copyWith(
      pendingInvites: item.pendingInvites
          .where((invite) => invite.contactId != contactId)
          .toList(growable: false),
    );

    notifyListeners();
  }

  @override
  Future<void> removeGroupMembers(
    String conversationId,
    Iterable<String> participantIds,
  ) async {
    final index = _indexOf(conversationId);
    if (index < 0) return;
    final item = _items[index];
    if (!item.isGroup) return;

    final actorRole = item.roleOf(currentUserId);
    if (actorRole != MessageGroupRole.leader) return;

    final ids = participantIds.toSet();
    final participants = item.participants
        .where((participant) {
          if (!ids.contains(participant.id)) return true;
          if (participant.id == currentUserId) return true;
          if (participant.role == MessageGroupRole.leader) return true;

          return false;
        })
        .toList(growable: false);

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
  void sendText({required String conversationId, required String text}) {
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
  Future<void> invitePeerToItinerary({
    required String conversationId,
    required String itineraryId,
  }) async {
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

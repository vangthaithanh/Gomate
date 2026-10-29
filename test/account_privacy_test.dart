import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/notifications/data/follow_request_repository.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/screens/notification_screen.dart';
import 'package:gomate/features/profile/screens/settings_preferences_screen.dart';
import 'package:gomate/features/profile/screens/public_profile_screen.dart';
import 'package:gomate/features/search/data/search_repository.dart';
import 'package:gomate/features/search/models/search_models.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

class _Inbox extends NotificationRepository {
  @override
  Future<void> refresh() async {}
}

class _Api {
  bool private = true;
  bool pending = true;
  bool failSave = false;
  bool failRequests = false;
  String? responseAction;
  int saves = 0;
  Map<String, dynamic> get profile => {
    'id': 'owner',
    'userId': 'owner',
    'nickname': 'Owner',
    'isPrivate': private,
    'onboardingCompleted': true,
  };
  late final AuthService auth = AuthService(
    baseUrl: 'http://localhost/api/v1',
    store: _Store(),
    client: MockClient((request) async {
      final path = request.url.path;
      Object value = profile;
      if (path.endsWith('/login')) {
        value = {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': profile,
        };
      } else if (request.method == 'PATCH') {
        saves++;
        if (failSave) {
          return http.Response(
            '{"code":"SERVER_ERROR","message":"unavailable"}',
            500,
          );
        }
        private = (jsonDecode(request.body) as Map)['isPrivate'] as bool;
        value = profile;
      } else if (path.endsWith('/follow-requests')) {
        if (failRequests) return http.Response('{"code":"SERVER_ERROR"}', 500);
        value = {
          'items': pending
              ? [
                  {
                    'id': 'request-1',
                    'requesterId': 'requester',
                    'nickname': 'Requester',
                    'status': 'PENDING',
                    'createdAt': '2026-10-21T10:00:00Z',
                  },
                ]
              : [],
          'total': pending ? 1 : 0,
        };
      } else if (path.contains('/follow-requests/')) {
        responseAction = path.split('/').last;
        pending = false;
        value = {};
      } else if (path.endsWith('/follow')) {
        value = {
          'followingByMe': false,
          'followsMe': true,
          'mutualFriend': false,
          'followRequestPending': request.method != 'DELETE',
          'isPrivate': true,
        };
      } else if (path.endsWith('/requester')) {
        value = {
          'id': 'requester',
          'nickname': 'Requester',
          'isPrivate': true,
          'followRequestPending': true,
          'followingByMe': false,
          'followsMe': true,
        };
      }
      return http.Response(
        jsonEncode(value),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  Future<void> login() => auth.login(
    email: 'owner@example.com',
    password: 'TestPass123!',
    remember: false,
  );
}

void main() {
  test(
    'real server privacy and pending state take precedence over reverse follow',
    () async {
      final api = _Api();
      await api.login();
      final repo = SearchRepository(auth: api.auth);
      final profile = await repo.getUserProfile('requester');
      expect(profile.isPrivate, isTrue);
      expect(profile.relation, SearchUserRelation.pending);
      expect(await repo.followUser('requester'), SearchUserRelation.pending);
      expect(
        await repo.unfollowUser('requester'),
        SearchUserRelation.followsYou,
      );
      expect(
        const SearchUserItem(
          id: 'a',
          name: 'A',
          subtitle: '',
          relation: SearchUserRelation.pending,
        ).actionLabel,
        'Chờ xác nhận',
      );
      api.auth.dispose();
    },
  );

  testWidgets(
    'Privacy switch reads server, persists changes and stays unchanged on failure',
    (tester) async {
      final api = _Api();
      await api.login();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsOptionsScreen(
            kind: SettingsOptionsKind.privacy,
            auth: api.auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(api.saves, 1);
      expect(api.private, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      api.failSave = true;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(
        find.text('Không lưu được quyền riêng tư. Vui lòng thử lại.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      api.auth.dispose();
    },
  );

  testWidgets('real private profile ignores legacy public UI hint', (
    tester,
  ) async {
    final api = _Api();
    await api.login();
    await tester.pumpWidget(
      MaterialApp(
        home: PublicProfileScreen(
          userId: 'requester',
          isPrivate: false,
          repository: SearchRepository(auth: api.auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    expect(find.text('Đây là trang cá nhân riêng tư'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.auth.dispose();
  });

  for (final accept in [true, false]) {
    testWidgets(
      'Follow request ${accept ? "accept" : "reject"} uses real endpoint and removes pending row',
      (tester) async {
        final api = _Api();
        await api.login();
        final inbox = _Inbox();
        await tester.pumpWidget(
          MaterialApp(
            home: GoMateNotificationScreen(
              repository: inbox,
              followRequests: FollowRequestRepository(auth: api.auth),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Yêu cầu theo dõi'), findsOneWidget);
        if (accept) {
          await tester.tap(find.text('Chấp nhận'));
        } else {
          await tester.tap(find.byTooltip('Từ chối'));
        }
        await tester.pumpAndSettle();
        expect(api.responseAction, accept ? 'accept' : 'reject');
        expect(
          find.byKey(const ValueKey('follow-request-request-1')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        api.auth.dispose();
        inbox.dispose();
      },
    );
  }

  testWidgets(
    'request error is visible; logout cannot retain previous owner queue',
    (tester) async {
      final api = _Api();
      await api.login();
      api.failRequests = true;
      final inbox = _Inbox();
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: inbox,
            followRequests: FollowRequestRepository(auth: api.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Không tải được yêu cầu theo dõi. Thử lại'),
        findsOneWidget,
      );
      api.failRequests = false;
      await tester.tap(find.text('Không tải được yêu cầu theo dõi. Thử lại'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('follow-request-request-1')),
        findsOneWidget,
      );
      await api.auth.clearLocal();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('follow-request-request-1')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      api.auth.dispose();
      inbox.dispose();
    },
  );
}

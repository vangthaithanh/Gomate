import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/core/widgets/gomate_notification_popup.dart';
import 'package:gomate/features/auth/screens/forgot_password_screen.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/models/gomate_notification.dart';
import 'package:gomate/features/notifications/screens/notification_screen.dart';
import 'package:gomate/features/profile/screens/profile_screen.dart';
import 'package:gomate/features/profile/screens/setting_screen.dart';
import 'package:gomate/features/posts/screens/create_post_screen.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/screens/trip_detail_screen.dart';

class _MemoryStore implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String text) async {}
}

Map<String, dynamic> _jsonItem(String id, {String status = 'PENDING'}) => {
  'id': 'notification-$id',
  'type': 'TRIP_INVITATION',
  'actorId': 'actor-$id',
  'actorName': 'Actor $id',
  'invitationId': 'invitation-$id',
  'invitationStatus': status,
  'tripId': 'trip-$id',
  'tripName': 'Trip $id',
  'occurredAt': DateTime.now().toUtc().toIso8601String(),
  'isRead': false,
};

class _Inbox extends NotificationRepository {
  final rows = [
    _jsonItem('A'),
    _jsonItem('B'),
  ].map(GoMateNotificationItem.fromJson).toList();
  int accepts = 0;
  bool failAccept = false;
  @override
  List<GoMateNotificationItem> get items => List.of(rows);
  @override
  bool get hasMore => false;
  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  @override
  Future<GoMateNotificationItem> resolve(String id) async =>
      rows.firstWhere((item) => item.id == id);
  @override
  Future<void> markRead(String id) async {
    final i = rows.indexWhere((item) => item.id == id);
    rows[i] = rows[i].copyWith(isRead: true);
    notifyListeners();
  }

  @override
  Future<TripUi> accept(GoMateNotificationItem item) async {
    accepts++;
    if (failAccept) throw StateError('network unavailable');
    final i = rows.indexWhere((row) => row.id == item.id);
    rows[i] = rows[i].copyWith(invitationStatus: 'ACCEPTED');
    notifyListeners();
    return TripUi(
      id: item.tripId!,
      title: item.tripName!,
      days: 2,
      destination: 'Test',
    );
  }
}

void main() {
  testWidgets('LF11 archived accepted notification cannot open active Trip', (
    tester,
  ) async {
    final inbox = _Inbox();
    inbox.rows
      ..clear()
      ..add(
        GoMateNotificationItem.fromJson({
          ..._jsonItem('A', status: 'ACCEPTED'),
          'tripId': null,
        }),
      );
    int loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GoMateNotificationScreen(
          repository: inbox,
          focusPendingInvitationId: 'notification-A',
          loadTrip: (_) async {
            loads++;
            throw StateError('Must not open archived Trip');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 0);
    expect(inbox.accepts, 0);
    expect(find.byType(TripDetailScreen), findsNothing);
    expect(find.text('Chấp nhận'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    inbox.dispose();
  });
  test(
    'Cancelled invitation is history, not an actionable pending invitation',
    () {
      final item = GoMateNotificationItem.fromJson(
        _jsonItem('A', status: 'CANCELLED'),
      );
      expect(item.isPendingInvitation, isFalse);
      expect(item.message, contains('đã hủy lời mời'));
    },
  );

  testWidgets('Cancelled invitation row cannot accept or open Trip', (
    tester,
  ) async {
    final inbox = _Inbox();
    inbox.rows[0] = GoMateNotificationItem.fromJson(
      _jsonItem('A', status: 'CANCELLED'),
    );
    inbox.rows.removeAt(1);
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GoMateNotificationScreen(
          repository: inbox,
          loadTrip: (_) async {
            loads++;
            throw StateError('Should not navigate');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chấp nhận'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification-A')));
    await tester.pumpAndSettle();
    expect(inbox.accepts, 0);
    expect(loads, 0);
    expect(find.byType(TripDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    inbox.dispose();
  });

  test(
    'Repository uses notification ID to read and invitation ID to accept; reload reads server status',
    () async {
      var status = 'PENDING';
      final paths = <String>[];
      final auth = AuthService(
        store: _MemoryStore(),
        baseUrl: 'http://localhost/api/v1',
        client: MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/login'))
            return http.Response(
              jsonEncode({
                'accessToken': 'test-access',
                'refreshToken': 'test-refresh',
                'user': {'id': 'user-test'},
              }),
              200,
            );
          if (request.url.path.endsWith('/notifications'))
            return http.Response(
              jsonEncode({
                'items': [_jsonItem('A', status: status)],
                'total': 1,
                'unreadCount': 1,
              }),
              200,
            );
          return http.Response(jsonEncode(_jsonItem('A', status: status)), 200);
        }),
      );
      await auth.login(
        email: 'test@example.com',
        password: 'TestPass123',
        remember: false,
      );
      final inbox = NotificationRepository(
        auth: auth,
        acceptInvitation: (invitationId) async {
          expect(invitationId, 'invitation-A');
          status = 'ACCEPTED';
          return const TripUi(
            id: 'trip-A',
            title: 'Trip A',
            days: 2,
            destination: 'Test',
          );
        },
      );
      await inbox.refresh();
      expect(inbox.items.single.isPendingInvitation, true);
      await inbox.markRead('notification-A');
      expect(paths.last, 'PATCH /api/v1/notifications/notification-A/read');
      expect(inbox.items.single.isPendingInvitation, true);
      await inbox.accept(inbox.items.single);
      expect(inbox.items.single.invitationStatus, 'ACCEPTED');
      await inbox.refresh();
      inbox.dispose();
      final restarted = NotificationRepository(auth: auth);
      await restarted.refresh();
      expect(restarted.items.single.isPendingInvitation, false);
      restarted.dispose();
    },
  );

  for (final width in [360.0, 430.0]) {
    testWidgets(
      'Popup -> inbox #1; pending body does not accept; approved row action only ($width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final inbox = _Inbox();
        late BuildContext homeContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                homeContext = context;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        );
        GoMateNotificationPopup.show(
          homeContext,
          message: 'Popup invitation B',
          onTap: () {
            GoMateNotificationScreen.openPendingInvitation(
              homeContext,
              notificationId: 'notification-B',
              repository: inbox,
            );
          },
        );
        await tester.pump();
        expect(find.text('Chấp nhận'), findsNothing);
        expect(find.byType(GoMateNotificationScreen), findsNothing);
        expect(inbox.accepts, 0);
        await tester.tap(find.text('Popup invitation B'));
        await tester.pumpAndSettle();
        expect(find.byType(GoMateNotificationScreen), findsOneWidget);
        final pinned = find.byKey(
          const ValueKey('pending-invite-notification-B'),
        );
        expect(pinned, findsOneWidget);
        expect(
          tester.getTopLeft(pinned).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('notification-A'))).dy,
          ),
        );
        expect(find.text('Từ chối'), findsNothing);
        await tester.tap(
          find.descendant(of: pinned, matching: find.byType(RichText)).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(GoMateNotificationScreen), findsOneWidget);
        expect(inbox.accepts, 0);
        await tester.tap(
          find.descendant(of: pinned, matching: find.text('Chấp nhận')),
        );
        await tester.pumpAndSettle();
        expect(inbox.accepts, 1);
        expect(
          find.byKey(const ValueKey('pending-invite-notification-B')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('notification-B')), findsOneWidget);
        expect(
          find.text('Chấp nhận'),
          findsOneWidget,
        ); // Only A is still pending.
        expect(tester.takeException(), isNull);
        GoMateNotificationPopup.dismiss();
        await tester.pumpWidget(const SizedBox());
        inbox.dispose();
      },
    );
  }

  testWidgets(
    'Accept failure retains pending notification and no false membership UI',
    (tester) async {
      final inbox = _Inbox()..failAccept = true;
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: inbox,
            focusPendingInvitationId: 'notification-B',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pending-invite-notification-B')),
          matching: find.text('Chấp nhận'),
        ),
      );
      await tester.pumpAndSettle();
      expect(inbox.items.last.isPendingInvitation, true);
      expect(
        find.byKey(const ValueKey('pending-invite-notification-B')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Không thể chấp nhận lời mời:'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      inbox.dispose();
    },
  );

  testWidgets(
    'Accepted row loads the exact business trip ID and returns to inbox',
    (tester) async {
      final inbox = _Inbox();
      inbox.rows[1] = inbox.rows[1].copyWith(invitationStatus: 'ACCEPTED');
      String? requestedTripId;
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: inbox,
            loadTrip: (id) async {
              requestedTripId = id;
              return TripUi(
                id: id,
                title: 'Accepted Trip B',
                days: 2,
                destination: 'Test',
                isGroup: true,
                currentUserRole: TripAccessRole.member,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notification-B')));
      await tester.pumpAndSettle();
      expect(requestedTripId, 'trip-B');
      expect(find.byType(TripDetailScreen), findsOneWidget);
      expect(find.text('Accepted Trip B'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(TripDetailScreen),
              matching: find.byIcon(LucideIcons.chevron_left),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoMateNotificationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      inbox.dispose();
    },
  );

  testWidgets(
    'New Profile and Settings open; Profile plus opens Create Post with camera cell',
    (tester) async {
      const photoManager = MethodChannel('com.fluttercandies/photo_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        photoManager,
        (_) async => 0,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          photoManager,
          null,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
      expect(find.textContaining('Demo UI'), findsNothing);
      // The header's first InkWell is the approved plus action.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(GoMateCreatePostScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('post-camera-cell')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Cài đặt và hoạt động'), findsOneWidget);
      expect(find.text('Hoạt động của bạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Approved change-password UI remains PIN-based and does not fake a sent PIN',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: ForgotPasswordScreen(changePasswordMode: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đổi mật khẩu'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final primary = find.text('Gửi mã');
      expect(primary, findsOneWidget);
      await tester.ensureVisible(primary);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text('Nhập mã pin'), findsNothing);
      expect(
        find.text('Đổi mật khẩu bằng mã PIN chưa khả dụng.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
